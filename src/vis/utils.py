from typing import Dict, List, Tuple, Any


Json = Dict[str, Any]


def recursively_insert_into_dict_tree(tree: Dict, keys: List[str], val: Any) -> Dict:
    """Recursively inserts a value into a nested tree of Dicts, creating new Dicts as necessary.

    Args:
        tree (Dict): A nested tree of Dicts.
        keys (List[str]): The path through the tree to the value.
        val (Any): The value to be inserted.

    Returns:
        Dict: The updated tree with val inserted as per the path specified by keys.
    """
    if keys == []:
        return tree
    key = keys[0]
    if len(keys) == 1:
        if isinstance(tree, Dict):
            if key in tree:
                tree[key].append(val)
            else:
                tree[key] = [val]
        if isinstance(tree, List):
            # TODO: Output Directories cause problems with uniqueness of names,
            # so for now we have to terminate the recursion.
            tree.append(val)
        return tree
    subtree = tree.get(key, {})
    tree[key] = recursively_insert_into_dict_tree(subtree, keys[1:], val)
    return tree


# Copied from wic to avoid wic dependency
def parse_provenance_output_files(output_json: Json) -> List[Tuple[str, str, str]]:
    """Parses the primary workflow provenance JSON object.

    Args:
        output_json (Json): The JSON results object, containing the metadata for all output files.

    Returns:
        List[Tuple[str, str, str]]: A List of (location, parentdirs, basename) for each output file.
    """
    files = []
    for namespaced_output_name, obj in output_json.items():
        files.append(parse_provenance_output_files_(obj, namespaced_output_name))
    return [y for x in files for y in x]


# Copied from wic to avoid wic dependency
def parse_provenance_output_files_(obj: Any, parentdirs: str) -> List[Tuple[str, str, str]]:
    """Parses the primary workflow provenance JSON object.

    Args:
        obj (Any): The provenance object or one of its recursive sub-objects.
        parentdirs (str): The directory associated with obj.

    Returns:
        List[Tuple[str, str, str]]: A List of (location, parentdirs, basename) for each output file.
    """
    if isinstance(obj, Dict):
        if obj.get('class', '') == 'File':
            return [(str(obj['location']), parentdirs, str(obj['basename']))]  # This basename is a file name
        if obj.get('class', '') == 'Directory':
            subdir = parentdirs + '/' + obj['basename']  # This basename is a directory name
            return parse_provenance_output_files_(obj['listing'], subdir)
    if isinstance(obj, List):
        files = []
        for o in obj:
            files.append(parse_provenance_output_files_(o, parentdirs))
        # Should we flatten?? This will lose the structure of 2D (and higher) array outputs.
        return [y for x in files for y in x]
    return []


def provenance_list_to_tree(files: List[Tuple[str, str, str]]) -> Dict:
    """Converts the flattened list of workflow steps into a nested tree of Dicts corresponding to subworkflows.

    Args:
        files (List[Tuple[str, str, str]]): This should be the output of parse_provenance_output_files(...)

    Returns:
        Dict: A nested tree of Dicts corresponding to subworkflows.
    """
    tree: Dict = {}
    for location, namespaced_output_name, basename in files:
        namespaces = namespaced_output_name.split('~')
        # print(yaml.dump(tree))
        # print((location, namespaced_output_name, basename))
        tree = recursively_insert_into_dict_tree(tree, namespaces, (location, namespaced_output_name, basename))
    return tree
