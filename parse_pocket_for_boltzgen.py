#!/usr/bin/env python3
"""
Parse fpocket pocket1 output and generate BoltzGen YAML configuration.
"""

import argparse
from pathlib import Path


def parse_pocket_residues(pocket_cif_file):
    """
    Extract unique residue numbers from fpocket pocket_atm.cif file.
    The auth_seq_id is at column index 14 in the ATOM/HETATM lines.
    """
    residues = set()

    with open(pocket_cif_file, 'r') as f:
        for line in f:
            # Only process ATOM and HETATM lines
            if line.startswith('ATOM') or line.startswith('HETATM'):
                parts = line.split()
                if len(parts) >= 15:
                    try:
                        # auth_seq_id is at index 14 (0-indexed)
                        res_num = int(parts[14])
                        residues.add(res_num)
                    except (ValueError, IndexError):
                        continue

    return sorted(residues)


def create_boltzgen_yaml(structure_file, pocket_residues, peptide_sequence, chain_id='A', output_file=None):
    """
    Create BoltzGen YAML configuration file.

    Args:
        structure_file: Path to the structure file (e.g., 4QKZ.cif)
        pocket_residues: List of residue numbers for binding hotspots
        peptide_sequence: Peptide sequence range (e.g., "14..20")
        chain_id: Chain ID of the target protein
        output_file: Output YAML filename
    """
    # Format residues as comma-separated string
    binding_residues = ','.join(map(str, pocket_residues))

    # Get structure filename
    structure_name = Path(structure_file).name

    # Generate YAML content
    yaml_content = f"""entities:
  - protein:
      id: B
      sequence: {peptide_sequence}
      cyclic: true
  - file:
      path: {structure_name}
      include:
        - chain:
            id: {chain_id}

binding_types:
  - chain:
      id: {chain_id}
      binding: {binding_residues}

structure_groups: "all"
"""

    # Write YAML file
    with open(output_file, 'w') as f:
        f.write(yaml_content)

    return binding_residues


def main():
    parser = argparse.ArgumentParser(
        description='Parse fpocket output and generate BoltzGen YAML configuration',
        epilog='Example: python parse_pocket_for_boltzgen.py -s 4QKZ.cif -p 4QKZ_out/pockets/pocket1_atm.cif -seq "14..20" -o 4QKZ_pocket1_cyclic.yaml'
    )
    parser.add_argument('-s', '--structure', required=True, help='Structure file (e.g., 4QKZ.cif)')
    parser.add_argument('-p', '--pocket', required=True, help='Pocket CIF file from fpocket (e.g., pocket1_atm.cif)')
    parser.add_argument('-seq', '--sequence', required=True, help='Peptide sequence range (e.g., "14..20")')
    parser.add_argument('-c', '--chain', default='A', help='Chain ID (default: A)')
    parser.add_argument('-o', '--output', required=True, help='Output YAML filename')

    args = parser.parse_args()

    # Check files exist
    if not Path(args.structure).exists():
        print(f"Error: Structure file not found: {args.structure}")
        return 1

    if not Path(args.pocket).exists():
        print(f"Error: Pocket file not found: {args.pocket}")
        return 1

    # Parse pocket residues
    print(f"Parsing pocket file: {args.pocket}")
    residues = parse_pocket_residues(args.pocket)

    if not residues:
        print("Error: No residues found in pocket file")
        return 1

    print(f"Found {len(residues)} unique residues in pocket")
    print(f"Residue range: {min(residues)} - {max(residues)}")

    # Create YAML
    print(f"\nGenerating BoltzGen YAML: {args.output}")
    binding_residues = create_boltzgen_yaml(
        args.structure,
        residues,
        args.sequence,
        args.chain,
        args.output
    )

    print(f"✓ YAML file created successfully!")
    print(f"\nConfiguration:")
    print(f"  Structure: {args.structure}")
    print(f"  Chain: {args.chain}")
    print(f"  Peptide sequence: {args.sequence}")
    print(f"  Binding residues ({len(residues)}): {binding_residues[:100]}{'...' if len(binding_residues) > 100 else ''}")

    return 0


if __name__ == '__main__':
    exit(main())
