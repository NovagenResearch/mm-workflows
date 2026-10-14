#!/usr/bin/env cwl-runner
cwlVersion: v1.0

class: CommandLineTool

label: DiffDock Diffusion pose ranking

doc: |-
  DiffDock Diffusion pose ranking

baseCommand: ["python", "/rank_diffdock_poses.py"]

hints:
  DockerRequirement:
    dockerPull: mrbrandonwalker/rank_diffdock_poses

requirements:
  InlineJavascriptRequirement: {}

inputs:

  diffdock_poses:
    label: diffdock poses
    type: File[]
    inputBinding:
      prefix: --diffdock_poses
    format:
      - edam:format_3814

  top_n_confident:
    type: int
    label: top n most confident poses to keep
    inputBinding:
      prefix: --top_n_confident
    # set default to essentially keep all poses
    default: 1000

  top_percent_confidence:
    type: float
    label: top percent of most confident poses to keep
    inputBinding:
      prefix: --top_percent_confidence
    # set default to keep all poses
    default: 100

outputs:

  output_poses:
    type: File[]
    label: top ranked poses
    outputBinding:
      glob: ranked_poses.txt # This determines what binds to self[0]
      loadContents: true
      outputEval: |
        ${
          // file looks like
          // file_index
          const lines = self[0].contents.split("\n").filter(line => line.trim() !== '');
          const lst = [];
          for (var i = 0; i < lines.length; i++) {
            var splitLine = lines[i].split(" ");
            // now find the File from inputs.diffdock_poses
            var mol_idx = parseInt(splitLine[0]);
            var file = inputs.diffdock_poses[mol_idx];
            lst.push(file);
          }
          return lst;
        }
    format: edam:format_3814

$namespaces:
  edam: https://edamontology.org/

$schemas:
- https://raw.githubusercontent.com/edamontology/edamontology/master/EDAM_dev.owl