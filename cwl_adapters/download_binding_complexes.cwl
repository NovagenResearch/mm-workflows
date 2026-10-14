#!/usr/bin/env cwl-runner
cwlVersion: v1.2

class: CommandLineTool

label: Download protein-ligand complexes with a measured Kd from the RCSB PDB

doc: |-
  Download protein-ligand complexes with a measured Kd from the RCSB PDB.
  Stands in for extract_pdbbind_refined, whose PDBbind download needs a login:
  it takes the inputs the workflows give that adapter and gives the same
  outputs, from a table of 40 complexes.

baseCommand: [python3, download_binding_complexes.py]

hints:
  DockerRequirement:
    dockerPull: python:3.12-slim

requirements:
  InlineJavascriptRequirement: {}
  NetworkAccess:
    networkAccess: true
  InitialWorkDirRequirement:
    listing:
    - entryname: download_binding_complexes.py
      entry: |
        """Protein-ligand complexes with a measured Kd, from the RCSB PDB.

        Each complex is a crystal structure (resolution <= 2.5 A) with one protein chain
        and one copy of the ligand. Kd is the lowest that RCSB PDB reports for the ligand
        (rcsb_binding_affinity, from BindingDB). The rows cover the four Kd ranges that
        docking_rescoring.wic selects, and 18 complexes have a Kd below 1 nM.
        """
        import argparse
        import math
        import time
        import urllib.request

        # (PDB id, ligand id, Kd in micromolar)
        COMPLEXES = [
            ('1b8o', 'IMH', 2.3e-05),
            ('2pk4', 'ACA', 9),
            ('2y6o', '1N1', 9e-05),
            ('3bra', 'AEF', 2000),
            ('3smq', 'TDU', 9.5),
            ('3uwn', 'UWN', 9.4),
            ('4er6', 'AW2', 6e-05),
            ('4fkv', '61K', 0.0822),
            ('4mre', '2C9', 6400),
            ('4mrf', '2CK', 6900),
            ('4mrh', '2CQ', 5400),
            ('4nyx', '2O4', 0.00039),
            ('4qb3', '30M', 0.0003),
            ('5anv', 'RGJ', 0.0005),
            ('5fbi', '5WD', 1600),
            ('5h8g', '5Y4', 4.8e-05),
            ('5jad', 'FB2', 3400),
            ('5kj2', '6TF', 1.28e-06),
            ('5llc', 'V26', 0.00039),
            ('5ml3', 'DL3', 0.00011),
            ('5ngz', '2BG', 1300),
            ('5u8a', '82D', 0.09),
            ('5w0e', '9U4', 0.0009),
            ('5x4m', '7ZF', 1200),
            ('5x4p', '7ZO', 9.3),
            ('6bbs', 'BZ1', 8.9e-05),
            ('6bc9', 'ETS', 4.3e-05),
            ('6iwi', 'B0C', 0.082),
            ('6mae', 'JBA', 6.5e-05),
            ('6qlo', 'J5E', 8.8),
            ('6r6f', 'EA3', 5e-05),
            ('6s4b', 'KUH', 0.085),
            ('6uwu', 'QKP', 0.084),
            ('6wtn', 'RXT', 3.6e-05),
            ('7mra', 'ZMJ', 0.082),
            ('7ms6', 'ZPV', 9),
            ('7ofd', 'VBW', 1800),
            ('7rh4', '5A4', 8.1),
            ('7ztz', 'DHT', 0.00025),
            ('8qh8', 'V8I', 0.00047),
        ]


        def fetch(url: str) -> str:
            """The body at url, retrying a network error twice."""
            for attempt in range(3):
                try:
                    with urllib.request.urlopen(url, timeout=120) as response:
                        return response.read().decode()
                except OSError:
                    if attempt == 2:
                        raise
                    time.sleep(60)
            raise AssertionError('unreachable')


        def without_ligand(pdb: str, ligand: str) -> str:
            """The entry without the ligand's HETATM records.

            CONECT records go too: some of them name the ligand's atoms.
            """
            return ''.join(line for line in pdb.splitlines(keepends=True)
                           if not line.startswith('CONECT')
                           and not (line.startswith('HETATM') and line[17:20].strip() == ligand))


        def element_case(sdf: str) -> str:
            """The SDF with element symbols written Cl, not CL: Open Babel reads CL as an unknown atom."""
            lines = sdf.split('\n')
            for i in range(4, 4 + int(lines[3][:3])):
                lines[i] = lines[i][:31] + lines[i][31:34].strip().capitalize().ljust(3) + lines[i][34:]
            return '\n'.join(lines)


        def main() -> None:
            """Write the binding data of the selected complexes, then download each one."""
            parser = argparse.ArgumentParser()
            parser.add_argument('--query', required=True)
            parser.add_argument('--max_row', type=int)
            parser.add_argument('--convert_Kd_dG', action='store_true')
            parser.add_argument('--output_txt_path', required=True)
            args = parser.parse_args()

            rows = []
            for pdb, ligand, kd in COMPLEXES:
                columns = {'PDB_code': pdb, 'ligand_name': ligand, 'Kd_Ki': 'Kd', 'value': kd}
                if eval(args.query, {'__builtins__': {}}, columns):  # pylint: disable=eval-used
                    rows.append((pdb, ligand, kd))
            rows = rows[:args.max_row]
            binding_data = []
            for pdb, _, kd in rows:
                kd_molar = kd * 1e-6
                # dG = RT ln(Kd) at 298 K, in kcal/mol, as generate_pdbbind_complex.py computes it
                dG = f' {8.31446261815324 / 4184 * 298 * math.log(kd_molar)}' if args.convert_Kd_dG else ''
                binding_data.append(f'{pdb} {kd_molar}{dG} Kd')
            with open(args.output_txt_path, mode='w', encoding='utf-8') as f:
                f.write('\n'.join(binding_data))

            for pdb, ligand, _ in rows:
                with open(f'{pdb}_protein.pdb', mode='w', encoding='utf-8') as f:
                    f.write(without_ligand(fetch(f'https://files.rcsb.org/download/{pdb}.pdb'), ligand))
                sdf = fetch(f'https://models.rcsb.org/v1/{pdb}/ligand?label_comp_id={ligand}&encoding=sdf')
                with open(f'{pdb}_ligand.sdf', mode='w', encoding='utf-8') as f:
                    f.write(element_case(sdf))


        if __name__ == '__main__':
            main()

inputs:
  query:
    label: Selects complexes
    doc: |-
      A Python expression over the columns PDB_code, ligand_name, Kd_Ki (always "Kd")
      and value (Kd in micromolar), e.g. (Kd_Ki == "Kd") and (value < 0.001)
    type: string
    inputBinding:
      prefix: --query

  max_row:
    label: Keeps the first max_row complexes the query selects
    type: int?
    inputBinding:
      prefix: --max_row

  convert_Kd_dG:
    label: If this is set to true, dG will be calculated
    type: boolean
    default: false
    inputBinding:
      prefix: --convert_Kd_dG

  output_txt_path:
    label: Path to the binding data file
    type: string
    default: binding_data.txt
    inputBinding:
      prefix: --output_txt_path

# Every array is read from the binding data file, one line per complex, so that the
# arrays keep its order: experimental dGs are compared with the predicted ones.
outputs:
  output_txt_path:
    label: Binding data, one line per complex - PDB id, Kd (mol/L), dG (kcal/mol, with convert_Kd_dG), Kd
    type: File
    format: edam:format_2330
    outputBinding:
      glob: $(inputs.output_txt_path)

  output_pdb_paths:
    label: The protein of each complex, without its ligand
    type: File[]
    format: edam:format_1476
    outputBinding:
      glob: $(inputs.output_txt_path)
      loadContents: true
      outputEval: |
        ${
          return self[0].contents.split("\n").map(function (line) {
            return {"class": "File", "path": line.split(" ")[0] + "_protein.pdb"};
          });
        }

  output_sdf_paths:
    label: The ligand of each complex
    type: File[]
    format: edam:format_3814
    outputBinding:
      glob: $(inputs.output_txt_path)
      loadContents: true
      outputEval: |
        ${
          return self[0].contents.split("\n").map(function (line) {
            return {"class": "File", "path": line.split(" ")[0] + "_ligand.sdf"};
          });
        }

  experimental_dGs:
    label: Experimental free energies of binding (with convert_Kd_dG)
    type: ["null", {"type": "array", "items": "float"}]
    outputBinding:
      glob: $(inputs.output_txt_path)
      loadContents: true
      outputEval: |
        ${
          var lines = self[0].contents.split("\n").filter(function (line) { return line.split(" ").length == 4; });
          return lines.length == 0 ? null : lines.map(function (line) { return parseFloat(line.split(" ")[2]); });
        }

  pdb_ids:
    label: The PDB id of each complex
    type: string[]
    outputBinding:
      glob: $(inputs.output_txt_path)
      loadContents: true
      outputEval: |
        ${
          return self[0].contents.split("\n").map(function (line) { return line.split(" ")[0]; });
        }

$namespaces:
  edam: https://edamontology.org/

$schemas:
- https://raw.githubusercontent.com/edamontology/edamontology/master/EDAM_dev.owl
