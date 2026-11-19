#!/usr/bin/env cwl-runner
cwlVersion: v1.2

class: CommandLineTool

label: Restrict a PDB file to a selection of atoms

doc: |-
  Restrict a PDB file to the atoms an mdtraj selection string selects, and save it.
  The image's driver runs examples/scripts/atomselect.py, given as script.

baseCommand: [python3, /python_cwl_driver.py, /workflow_types.py]

hints:
  DockerRequirement:
    dockerPull: jakefennick/atomselect

inputs:
  script:
    label: The script to run, examples/scripts/atomselect.py
    type: File
    format: edam:format_2330
    inputBinding:
      position: 1

  selection_string:
    label: Selection string for mdtraj
    type: string
    format: edam:format_2330
    inputBinding:
      position: 2
      prefix: --selection_string

  input_pdb_path:
    label: Input pdb file path
    type: File
    format: edam:format_1476
    inputBinding:
      position: 3
      prefix: --input_pdb_path

  output_pdb_path:
    label: Output pdb file path
    type: string
    format: edam:format_2330
    default: selection.pdb
    inputBinding:
      position: 4
      prefix: --output_pdb_path

outputs:
  output_pdb_path:
    label: Output pdb file path
    type: File
    format: edam:format_1476
    outputBinding:
      glob: $(inputs.output_pdb_path)

$namespaces:
  edam: https://edamontology.org/
