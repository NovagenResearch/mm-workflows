#!/usr/bin/env cwl-runner
cwlVersion: v1.2

class: CommandLineTool

label: Plot NMR relaxation from a trajectory

doc: |-
  Plot the NMR relaxation time and correlation function of the hydrogens of a trajectory, with nmrformd.
  The image's driver runs examples/scripts/nmr4md.py, given as script.

baseCommand: [python3, /python_cwl_driver.py, /workflow_types.py]

hints:
  DockerRequirement:
    dockerPull: jakefennick/nmr4md

inputs:
  script:
    label: The script to run, examples/scripts/nmr4md.py
    type: File
    format: edam:format_2330
    inputBinding:
      position: 1

  input_tpr_path:
    label: Input tpr file path
    type: File
    format: edam:format_2333
    inputBinding:
      position: 2
      prefix: --input_tpr_path

  input_trr_path:
    label: Input trr file path
    type: File
    format: edam:format_3910
    inputBinding:
      position: 3
      prefix: --input_trr_path

  output_png_path:
    label: Output png file path
    type: string
    format: edam:format_2330
    default: nmr.png
    inputBinding:
      position: 4
      prefix: --output_png_path

outputs:
  output_png_path:
    label: Output png file path
    type: File
    format: edam:format_3603
    outputBinding:
      glob: $(inputs.output_png_path)

$namespaces:
  edam: https://edamontology.org/
