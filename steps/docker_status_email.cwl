#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool

requirements:
- class: InlineJavascriptRequirement
- class: InitialWorkDirRequirement
  listing:
  - entryname: validation_email.py
    entry: |
      #!/usr/bin/env python
      import synapseclient
      import argparse
      import json
      import os

      parser = argparse.ArgumentParser()
      parser.add_argument("-s", "--submissionid", required=True, help="Submission ID")
      parser.add_argument("-c", "--synapse_config", required=True, help="credentials file")
      parser.add_argument("--status", required=True, help="Prediction File Status")
      parser.add_argument("-i","--invalid", required=True, help="Invalid reasons")

      args = parser.parse_args()
      syn = synapseclient.Synapse(configPath=args.synapse_config)
      syn.login()

      sub = syn.getSubmission(args.submissionid)
      participantid = sub.get("teamId")
      if participantid is not None:
        name = syn.getTeam(participantid)['name']
      else:
        participantid = sub.userId
        name = syn.getUserProfile(participantid)['userName']
      evaluation = syn.getEvaluation(sub.evaluationId)

      if args.status == "INVALID":
        subject = "Submission to '%s' invalid!" % evaluation.name
        message = ["Hello %s,\n\n" % name,
                    "We ran your submission (id: %s) against the training data but could not generate a predictions file.  Please check the log file from the Submission Dashboard for more info." % sub.id,
                    "\n\nSincerely,\nChallenge Administrator"]
      else:
        subject = "Submission to '%s' valid!" % evaluation.name
        message = ["Hello %s,\n\n" % name,
                    "We ran your submission (id: %s) against the training data and was able to generate a predictions file!  Feel free to submit your model to the official queue(s).\n\n" % sub.id,
                    "Note: this queue does guarantee the success of running your model against the test data.\n\n",
                    "Sincerely,\nChallenge Administrator"]
      syn.sendMessage(
            userIds=[participantid],
            messageSubject=subject,
            messageBody="".join(message))

inputs:
- id: submissionid
  type: int
- id: synapse_config
  type: File
- id: status
  type: string
- id: invalid_reasons
  type: string

outputs:
- id: finished
  type: boolean
  outputBinding:
    outputEval: $( true )

baseCommand: python3
arguments:
- valueFrom: validation_email.py
- prefix: -s
  valueFrom: $(inputs.submissionid)
- prefix: -c
  valueFrom: $(inputs.synapse_config.path)
- prefix: --status
  valueFrom: $(inputs.status)
- prefix: -i
  valueFrom: $(inputs.invalid_reasons)

hints:
  DockerRequirement:
    dockerPull: sagebionetworks/synapsepythonclient:v2.6.0
