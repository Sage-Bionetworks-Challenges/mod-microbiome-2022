#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: Run Docker submission

requirements:
- class: InitialWorkDirRequirement
  listing:
  - $(inputs.docker_script)
  - entryname: .docker/config.json
    entry: |
      {"auths": {"$(inputs.docker_registry)": {"auth": "$(inputs.docker_authentication)"}}}
- class: InlineJavascriptRequirement

inputs:
- id: submissionid
  type: int
- id: docker_repository
  type: string
- id: docker_digest
  type: string
- id: docker_registry
  type: string
- id: docker_authentication
  type: string
- id: parentid
  type: string
- id: synapse_config
  type: File
- id: input_dir
  type: string
- id: docker_script
  type: File
- id: store
  type: boolean?

outputs:
- id: predictions
  type: File?
  outputBinding:
    glob: predictions.csv
- id: results
  type: File
  outputBinding:
    glob: results.json
- id: status
  type: string
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['submission_status'])
    loadContents: true
- id: invalid_reasons
  type: string
  outputBinding:
    glob: results.json
    outputEval: $(JSON.parse(self[0].contents)['submission_errors'])
    loadContents: true

baseCommand: python3
arguments:
- valueFrom: $(inputs.docker_script.path)
- prefix: -s
  valueFrom: $(inputs.submissionid)
- prefix: -p
  valueFrom: $(inputs.docker_repository)
- prefix: -d
  valueFrom: $(inputs.docker_digest)
- prefix: --store
  valueFrom: $(inputs.store)
- prefix: --parentid
  valueFrom: $(inputs.parentid)
- prefix: -c
  valueFrom: $(inputs.synapse_config.path)
- prefix: -i
  valueFrom: $(inputs.input_dir)
- prefix: -t
  valueFrom: $(inputs.task_number)
