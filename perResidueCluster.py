#!/usr/bin/env python3
"""
Cluster cyclic peptide structures by backbone RMSD using cookie-cutter approach.
Based on Qiyao's clustering algorithm.
"""

import numpy as np
from pathlib import Path
import json
from typing import Dict, List, Tuple
import gemmi  # For parsing CIF files


def kabsch_algorithm(P: np.ndarray, Q: np.ndarray) -> Tuple[np.ndarray, np.ndarray, float]:
    """
    Calculate optimal rigid body transformation using Kabsch algorithm.
    
    Args:
        P: Nx3 array of points to be aligned
        Q: Nx3 array of target points
    
    Returns:
        R: 3x3 rotation matrix
        t: 3x1 translation vector
        rmsd: root-mean-square deviation
    """
    # Calculate centroids
    centroid_P = np.mean(P, axis=0)
    centroid_Q = np.mean(Q, axis=0)
    
    # Center the points
    P_centered = P - centroid_P
    Q_centered = Q - centroid_Q
    
    # Covariance matrix
    H = P_centered.T @ Q_centered
    
    # SVD
    U, S, Vt = np.linalg.svd(H)
    
    # Rotation matrix
    R = Vt.T @ U.T
    
    # Handle reflection case
    if np.linalg.det(R) < 0:
        Vt[-1, :] *= -1
        R = Vt.T @ U.T
    
    # Translation vector
    t = centroid_Q - R @ centroid_P
    
    # Apply transformation and calculate RMSD
    P_aligned = (R @ P.T).T + t
    rmsd = np.sqrt(np.sum((Q - P_aligned)**2) / len(P))
    
    return R, t, rmsd


def extract_backbone_coords(cif_file: Path) -> Tuple[np.ndarray, int]:
    """
    Extract backbone atom coordinates (N, CA, C, O) from CIF file.
    
    Args:
        cif_file: Path to CIF file
    
    Returns:
        coords: Nx3 array of backbone coordinates (N*4 atoms x 3 coords)
        n_residues: Number of residues
    """
    structure = gemmi.read_structure(str(cif_file))
    model = structure[0]
    
    backbone_atoms = []
    atom_names = ['N', 'CA', 'C', 'O']
    
    for chain in model:
        for residue in chain:
            for atom_name in atom_names:
                atom = residue.find_atom(atom_name, '\x00')
                if atom:
                    pos = atom.pos
                    backbone_atoms.append([pos.x, pos.y, pos.z])
    
    coords = np.array(backbone_atoms)
    n_residues = len(coords) // 4
    
    return coords, n_residues


def parse_score_file(score_file: Path) -> Dict[str, float]:
    """
    Parse the sorted score file to get structure names and scores.
    
    Args:
        score_file: Path to combined_filtered_scores_sorted.sc
    
    Returns:
        Dictionary mapping structure_name to min_internal_hbonds score
    """
    scores = {}
    with open(score_file, 'r') as f:
        lines = f.readlines()
        # Skip header line
        for line in lines[1:]:
            parts = line.strip().split()
            if len(parts) >= 3:
                # Structure name in score file is like "1a85_cyclic_044_chainA.cif"
                structure_name = parts[1]
                score = float(parts[2])
                scores[structure_name] = score
    
    return scores


def cluster_structures(coords_dict: Dict[str, np.ndarray], 
                       structure_order: List[str],
                       rmsd_cutoff: float = 1.5) -> Dict[str, List[str]]:
    """
    Cluster structures using cookie-cutter approach.
    
    Args:
        coords_dict: Dictionary mapping structure_name to backbone coordinates
        structure_order: List of structure names sorted by score (ascending)
        rmsd_cutoff: RMSD cutoff for clustering in Angstroms
    
    Returns:
        Dictionary mapping cluster representative to list of cluster members
    """
    unclustered = set(structure_order)
    clusters = {}
    
    while unclustered:
        # Get the lowest energy unclustered structure
        center = None
        for struct in structure_order:
            if struct in unclustered:
                center = struct
                break
        
        if center is None:
            break
        
        center_coords = coords_dict[center]
        members = [center]
        
        # Find all structures within RMSD cutoff
        for struct in list(unclustered):
            if struct == center:
                continue
            
            struct_coords = coords_dict[struct]
            
            # Calculate RMSD using Kabsch algorithm
            _, _, rmsd = kabsch_algorithm(struct_coords, center_coords)
            
            if rmsd < rmsd_cutoff:
                members.append(struct)
        
        # Remove all cluster members from unclustered set
        for member in members:
            unclustered.discard(member)
        
        clusters[center] = members
        print(f"Cluster {len(clusters)}: Representative {center}, {len(members)} members, RMSD < {rmsd_cutoff} Å")
    
    return clusters


def main():
    # Set up paths - assume running from directory with CIF files
    base_dir = Path('.')
    output_dir = Path('.')
    
    score_file = base_dir / 'combined_filtered_scores_sorted.sc'
    
    print("Loading scores from file...")
    scores = parse_score_file(score_file)
    print(f"Loaded {len(scores)} structures with scores")
    
    # Load all CIF files and extract coordinates
    print("\nExtracting backbone coordinates from CIF files...")
    coords_by_length = {}  # Group by number of residues
    structure_info = {}  # Store (n_residues, score) for each structure
    
    cif_files = list(base_dir.glob('alpha_*_chainA.cif'))
    print(f"Found {len(cif_files)} CIF files")
    
    if cif_files:
        print(f"Example CIF file name: {cif_files[0].name}")
    if scores:
        print(f"Example score key: {list(scores.keys())[0]}")
    
    for cif_file in cif_files:
        structure_name = cif_file.name
        
        # Extract base name without alpha prefix: alpha_0.01_1a85_cyclic_044_chainA.cif -> 1a85_cyclic_044_chainA.cif
        base_name = '_'.join(structure_name.split('_')[2:])  # Skip alpha_X.XX prefix
        
        # Only process structures that are in the score file
        if base_name not in scores:
            continue
        
        try:
            coords, n_residues = extract_backbone_coords(cif_file)
            
            if n_residues not in coords_by_length:
                coords_by_length[n_residues] = {}
            
            coords_by_length[n_residues][structure_name] = coords
            structure_info[structure_name] = (n_residues, scores[base_name])
            
        except Exception as e:
            print(f"Warning: Could not process {structure_name}: {e}")
    
    print(f"\nSuccessfully loaded {len(structure_info)} structures")
    print(f"Peptide lengths found: {sorted(coords_by_length.keys())}")
    
    # Cluster by length group
    all_clusters = {}
    all_representatives = []
    
    for length in sorted(coords_by_length.keys()):
        print(f"\n{'='*60}")
        print(f"Clustering peptides with {length} residues")
        print(f"{'='*60}")
        
        coords_dict = coords_by_length[length]
        
        # Sort structures by score for this length
        # Need to extract base name for score lookup
        structures_this_length = list(coords_dict.keys())
        
        def get_score(struct_name):
            base_name = '_'.join(struct_name.split('_')[2:])
            return scores[base_name]
        
        structures_sorted = sorted(structures_this_length, key=get_score)
        
        print(f"Found {len(structures_sorted)} structures with {length} residues")
        
        # Perform clustering
        clusters = cluster_structures(coords_dict, structures_sorted, rmsd_cutoff=1.5)
        
        # Store results
        for rep, members in clusters.items():
            base_name = '_'.join(rep.split('_')[2:])
            all_clusters[rep] = {
                'members': members,
                'n_residues': length,
                'n_members': len(members),
                'representative_score': scores[base_name]
            }
            all_representatives.append(rep)
    
    # Save results
    print(f"\n{'='*60}")
    print(f"CLUSTERING COMPLETE")
    print(f"{'='*60}")
    print(f"Total number of clusters: {len(all_clusters)}")
    print(f"Total structures clustered: {sum(c['n_members'] for c in all_clusters.values())}")
    
    # Save cluster information as JSON
    output_json = output_dir / 'clusters.json'
    with open(output_json, 'w') as f:
        json.dump(all_clusters, f, indent=2)
    print(f"\nCluster details saved to: {output_json}")
    
    # Save list of cluster representatives
    output_txt = output_dir / 'cluster_representatives.txt'
    with open(output_txt, 'w') as f:
        f.write("# Cluster representatives (sorted by score)\n")
        f.write("# Representative\tN_residues\tN_members\tScore\n")
        
        # Sort representatives by score
        reps_sorted = sorted(all_representatives, 
                            key=lambda r: all_clusters[r]['representative_score'])
        
        for rep in reps_sorted:
            info = all_clusters[rep]
            f.write(f"{rep}\t{info['n_residues']}\t{info['n_members']}\t{info['representative_score']:.3f}\n")
    
    print(f"Cluster representatives saved to: {output_txt}")
    
    # Print summary by length
    print("\nSummary by peptide length:")
    for length in sorted(coords_by_length.keys()):
        n_structures = len(coords_by_length[length])
        n_clusters = sum(1 for c in all_clusters.values() if c['n_residues'] == length)
        print(f"  {length} residues: {n_structures} structures → {n_clusters} clusters")


if __name__ == '__main__':
    main()
