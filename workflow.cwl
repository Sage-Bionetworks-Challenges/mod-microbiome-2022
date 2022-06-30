#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: UCSF Microbiome Challenge Evaluation
doc: |
  This workflow will run and evaluate a Docker submission to the MOD - Preterm
  Birth Prediction Microbiome Challenge (syn26133771). Metrics returned are ROC,
  PR, Accuracy, Sensitivity, Specificity.

requirements:
- class: StepInputExpressionRequirement

inputs:
  adminUploadSynId:
    label: Synapse Folder ID accessible by an admin
    type: string
  submissionId:
    label: Submission ID
    type: int
  submitterUploadSynId:
    label: Synapse Folder ID accessible by the submitter
    type: string
  synapseConfig:
    label: filepath to .synapseConfig file
    type: File
  workflowSynapseId:
    label: Synapse File ID that links to the workflow
    type: string

outputs: {}

steps:

  determine_question:
    run: steps/determine_question.cwl
    in:
      - id: queue
        source: "#get_docker_submission/evaluation_id"
    out:
      - id: task_number

  set_submitter_folder_permissions:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#submitterUploadSynId"
      - id: principalid
        valueFrom: "3433368"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  set_admin_folder_permissions:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/set_permissions.cwl
    in:
      - id: entityid
        source: "#adminUploadSynId"
      - id: principalid
        valueFrom: "3433368"
      - id: permissions
        valueFrom: "download"
      - id: synapse_config
        source: "#synapseConfig"
    out: []

  get_docker_submission:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/get_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath
      - id: docker_repository
      - id: docker_digest
      - id: entity_id
      - id: entity_type
      - id: evaluation_id
      - id: results

  get_docker_config:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/get_docker_config.cwl
    in:
      - id: synapse_config
        source: "#synapseConfig"
    out: 
      - id: docker_registry
      - id: docker_authentication

  validate_docker:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/validate_docker.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: results
      - id: status
      - id: invalid_reasons

  email_docker_validation:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#validate_docker/status"
      - id: invalid_reasons
        source: "#validate_docker/invalid_reasons"
      - id: errors_only
        default: true
    out: [finished]

  annotate_docker_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate_docker/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  check_docker_status:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#validate_docker/status"
      - id: previous_annotation_finished
        source: "#annotate_docker_validation_with_output/finished"
      - id: previous_email_finished
        source: "#email_docker_validation/finished"
    out: [finished]

  run_docker_on_training:
    run: steps/run_docker.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: submissionid
        source: "#submissionId"
      - id: docker_registry
        source: "#get_docker_config/docker_registry"
      - id: docker_authentication
        source: "#get_docker_config/docker_authentication"
      - id: status
        source: "#validate_docker/status"
      - id: parentid
        source: "#submitterUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: store
        default: true
      - id: input_dir
        valueFrom: "/home/ec2-user/training_data"
      - id: name_prefix
        valueFrom: "training"
      - id: docker_script
        default:
          class: File
          location: "run_docker.py"
    out:
      - id: predictions

  upload_training_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/upload_to_synapse.cwl
    in:
      - id: infile
        source: "#run_docker_on_training/predictions"
      - id: parentid
        source: "#adminUploadSynId"
      - id: used_entity
        source: "#get_docker_submission/entity_id"
      - id: executed_entity
        source: "#workflowSynapseId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: uploaded_fileid
      - id: uploaded_file_version
      - id: results

  annotate_docker_upload_training_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#upload_training_results/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_docker_validation_with_output/finished"
    out: [finished]

  download_training_goldstandard:
    run: https://raw.githubusercontent.com/Sage-Bionetworks-Workflows/cwl-tool-synapseclient/v1.4/cwl/synapse-get-tool.cwl
    in:
      - id: synapseid
        valueFrom: "syn31620119"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath

  validate_training:
    run: steps/validate.cwl
    in:
      - id: input_file
        source: "#run_docker_on_training/predictions"
      - id: goldstandard
        source: "#download_training_goldstandard/filepath"
      - id: task_number
        source: "#determine_question/task_number"
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  email_validation_training:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#validate_training/status"
      - id: invalid_reasons
        source: "#validate_training/invalid_reasons"
      # OPTIONAL: set `default` to `false` if email notification about valid submission is needed
      - id: errors_only
        default: true
    out: [finished]

  annotate_validation_with_training_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate_training/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_docker_upload_training_results/finished"
    out: [finished]

  check_status_training:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#validate_training/status"
      - id: previous_annotation_finished
        source: "#annotate_validation_with_training_output/finished"
      - id: previous_email_finished
        source: "#email_validation_training/finished"
    out: [finished]

  score_training:
    run: steps/score.cwl
    in:
      - id: input_file
        source: "#run_docker_on_training/predictions"
      - id: goldstandard
        source: "#download_training_goldstandard/filepath"
      - id: task_number
        source: "#determine_question/task_number"
      - id: check_validation_finished 
        source: "#check_status_training/finished"
    out:
      - id: results
      
  email_score_training:
    run: steps/send_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: results
        source: "#score_training/results"
      - id: private_annotations
        default: ["mcc"]
    out: []

  annotate_submission_with_training_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#score_training/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_validation_with_training_output/finished"
    out: [finished]
 
  run_docker:
    run: steps/run_docker.cwl
    in:
      - id: docker_repository
        source: "#get_docker_submission/docker_repository"
      - id: docker_digest
        source: "#get_docker_submission/docker_digest"
      - id: submissionid
        source: "#submissionId"
      - id: docker_registry
        source: "#get_docker_config/docker_registry"
      - id: docker_authentication
        source: "#get_docker_config/docker_authentication"
      - id: status
        source: "#validate_docker/status"
      - id: parentid
        source: "#submitterUploadSynId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: store
        default: true
      - id: input_dir
        valueFrom: "/home/ec2-user/training_data"
      - id: name_prefix
        valueFrom: "testing"
      - id: docker_script
        default:
          class: File
          location: "run_docker.py"
    out:
      - id: predictions

  upload_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/upload_to_synapse.cwl
    in:
      - id: infile
        source: "#run_docker/predictions"
      - id: parentid
        source: "#adminUploadSynId"
      - id: used_entity
        source: "#get_docker_submission/entity_id"
      - id: executed_entity
        source: "#workflowSynapseId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: uploaded_fileid
      - id: uploaded_file_version
      - id: results

  annotate_docker_upload_results:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#upload_results/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_submission_with_training_output/finished"
    out: [finished]

  download_goldstandard:
    run: https://raw.githubusercontent.com/Sage-Bionetworks-Workflows/cwl-tool-synapseclient/v1.4/cwl/synapse-get-tool.cwl
    in:
      - id: synapseid
        valueFrom: "syn31620119"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath
  
  validate:
    run: steps/validate.cwl
    in:
      - id: input_file
        source: "#run_docker/predictions"
      - id: goldstandard
        source: "#download_goldstandard/filepath"
      - id: task_number
        source: "#determine_question/task_number"
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  email_validation:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#validate/status"
      - id: invalid_reasons
        source: "#validate/invalid_reasons"
      # OPTIONAL: set `default` to `false` if email notification about valid submission is needed
      - id: errors_only
        default: true
    out: [finished]

  annotate_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validate/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_docker_upload_results/finished"
    out: [finished]

  check_status:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#validate/status"
      - id: previous_annotation_finished
        source: "#annotate_validation_with_output/finished"
      - id: previous_email_finished
        source: "#email_validation/finished"
    out: [finished]

  score:
    run: steps/score.cwl
    in:
      - id: input_file
        source: "#run_docker/predictions"
      - id: goldstandard
        source: "#download_goldstandard/filepath"
      - id: task_number
        source: "#determine_question/task_number"
      - id: check_validation_finished 
        source: "#check_status/finished"
    out:
      - id: results
      
  email_score:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/score_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: results
        source: "#score/results"
      - id: private_annotations
        default: ["mcc"]
    out: []

  annotate_submission_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#score/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_validation_with_output/finished"
    out: [finished]
 