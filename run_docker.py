"""Run training synthetic docker models"""
from __future__ import print_function
import argparse
import os
import tarfile
import time
import json

import synapseclient
import docker


def create_log_file(log_filename, log_text=None):
    """Create log file"""
    with open(log_filename, 'w') as log_file:
        if log_text is not None:
            if isinstance(log_text, bytes):
                log_text = log_text.decode("utf-8")
            log_file.write(log_text.encode("ascii", "ignore").decode("ascii"))
        else:
            log_file.write("No Logs")


def get_last_lines(log_filename, n=5):
    """Get last N lines of log file (default=5)."""
    lines = 0
    with open(log_filename, "rb") as f:
        try:
            f.seek(-2, os.SEEK_END)
            while lines < n:
                f.seek(-2, os.SEEK_CUR)
                if f.read(1) == b"\n":
                    lines += 1
        except OSError:
            f.seek(0)
        last_lines = f.read().decode()
    return last_lines


def store_log_file(syn, log_filename, parentid, store=True):
    """Store log file"""
    statinfo = os.stat(log_filename)
    if statinfo.st_size > 0:
        # If log file is larger than 50Kb, only save last 5 lines.
        if statinfo.st_size/1000.0 > 50:
            log_tail = get_last_lines(log_filename)
            create_log_file(log_filename, log_tail)
        ent = synapseclient.File(log_filename, parent=parentid)

        if store:
            try:
                syn.store(ent)
            except synapseclient.exceptions.SynapseHTTPError as err:
                print(err)


def remove_docker_container(container_name):
    """Remove docker container"""
    client = docker.from_env()
    try:
        cont = client.containers.get(container_name)
        cont.stop()
        cont.remove()
    except Exception:
        print("Unable to remove container")


def remove_docker_image(image_name):
    """Remove docker image"""
    client = docker.from_env()
    try:
        client.images.remove(image_name, force=True)
    except Exception:
        print("Unable to remove image")


def tar(directory, tar_filename):
    """Tar all files in a directory

    Args:
        directory: Directory path to files to tar
        tar_filename:  tar file path
    """
    with tarfile.open(tar_filename, "w") as tar_o:
        tar_o.add(directory)


def untar(directory, tar_filename):
    """Untar a tar file into a directory

    Args:
        directory: Path to directory to untar files
        tar_filename:  tar file path
    """
    with tarfile.open(tar_filename, "r") as tar_o:
        tar_o.extractall(path=directory)


def main(syn, args):
    """Run docker model"""
    client = docker.DockerClient(base_url='unix://var/run/docker.sock')
    config = synapseclient.Synapse().getConfigFile(
        configPath=args.synapse_config
    )
    authen = dict(config.items("authentication"))
    client.login(username=authen['username'],
                 password=authen['password'],
                 registry="https://docker.synapse.org")

    # Get Docker image to run and volumes to be mounted.
    docker_image = args.docker_repository + "@" + args.docker_digest
    output_dir = os.getcwd()
    if args.task_number == "1":
        input_dir = "/home/ec2-user/task1_input"
    else:
        input_dir = "/home/ec2-user/task2_input"
    container_name = f"{args.submissionid}_task{args.task_number}"

    print("mounting volumes")
    mounted_volumes = {output_dir: '/output:rw',
                       input_dir: '/input:ro'}

    # Format the mounted volumes so that Docker SDK can understand.
    all_volumes = [output_dir, input_dir]
    volumes = {}
    for vol in all_volumes:
        volumes[vol] = {'bind': mounted_volumes[vol].split(":")[0],
                        'mode': mounted_volumes[vol].split(":")[1]}

    # Look for if the container exists already, if so, reconnect
    print("checking for containers")
    container = None
    errors = None
    for cont in client.containers.list(all=True, ignore_removed=True):
        if container_name in cont.name:
            # Must remove container if the container wasn't killed properly
            if cont.status == "exited":
                cont.remove()
            else:
                container = cont

    # Run the Docker container in detached mode.
    if container is None:
        print("running container")
        try:
            container = client.containers.run(docker_image,
                                              detach=True,
                                              volumes=volumes,
                                              name=container_name,
                                              network_disabled=True,
                                              mem_limit='18g',
                                              stderr=True,
                                              runtime="nvidia")
        except docker.errors.APIError as err:
            container = None
            remove_docker_container(container_name)
            errors = str(err) + "\n"
        else:
            errors = ""

    # Create a logfile to catch stdout/stderr from the Docker runs.
    print("creating logfile")
    log_filename = args.submissionid + "_log.txt"
    open(log_filename, 'w').close()

    # While container is running, capture logs every 60s. Remove container
    # when done.
    if container is not None:
        while container in client.containers.list(ignore_removed=True):
            log_text = container.logs()
            create_log_file(log_filename, log_text=log_text)
            store_log_file(syn, log_filename, args.parentid, store=args.store)
            time.sleep(60)

        # Must run again to make sure all the logs are captured.
        log_text = container.logs()
        create_log_file(log_filename, log_text=log_text)
        store_log_file(syn, log_filename, args.parentid, store=args.store)

        container.remove()

    statinfo = os.stat(log_filename)
    if statinfo.st_size == 0 and errors:
        create_log_file(log_filename, log_text=errors)
        store_log_file(syn, log_filename, args.parentid, store=args.store)

    print("finished running Docker model")
    remove_docker_image(docker_image)

    # Check for prediction files once the Docker run is complete.
    output_folder = os.listdir(output_dir)
    if not output_folder or "predictions.csv" not in output_folder:
        status = "INVALID"
        errors = ("Error encountered while running your Docker container; contact "
                  "the Challenge Organizers in the Discussion Board for more info.")
    else:
        status = "VALIDATED"
        errors = ""
    with open("results.json", "w") as out:
        out.write(json.dumps({
            'submission_status': status,
            'submission_errors': errors,
            'admin_folder': args.parentid
        }))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--submissionid", required=True,
                        help="Submission Id")
    parser.add_argument("-p", "--docker_repository", required=True,
                        help="Docker Repository")
    parser.add_argument("-d", "--docker_digest", required=True,
                        help="Docker Digest")
    parser.add_argument("-t", "--task_number", choices=["1", "2"],
                        required=True, help="Task number of submission")
    parser.add_argument("-c", "--synapse_config", required=True,
                        help="credentials file")
    parser.add_argument("--store", action='store_true',
                        help="to store logs")
    parser.add_argument("--parentid", required=True,
                        help="Parent Id of submitter directory")
    args = parser.parse_args()
    syn = synapseclient.Synapse(configPath=args.synapse_config)
    syn.login()
    main(syn, args)
