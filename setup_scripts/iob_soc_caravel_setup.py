import os
import shutil
import sys
import json
import re
import importlib


def find_module_instantiations(verilog_file_path):
    module_names = set()
    module_pattern = r"^(?!module).*\b\w+\s*#\s*\([\s\S]*?;\s*$"
    with open(verilog_file_path, "r") as file:
        verilog_code = file.read()
        # Search for module instantiations using regex
        matches = re.findall(module_pattern, verilog_code, re.MULTILINE)
        # Extract module names from the matches
        for match in matches:
            # Capture the module name pattern
            for match in matches:
                # Capture the module name pattern
                module_name = match.split()[0] + ".v"
                module_names.add(module_name)
    return list(module_names)


def find_includes_vh(file_path):
    with open(file_path, "r") as file:
        verilog_code = file.read()
        include_pattern = re.compile(r'`include\s+"([^"]+)"')
        matches = include_pattern.findall(verilog_code)
        return matches


def search_file_iname(
    start_dir, name
):  # a simple search algorithm that does not enter the .git folder
    for foldername, subfolders, filenames in os.walk(start_dir):
        if ".git" in subfolders:
            subfolders.remove(".git")  # Exclude the .git folder from the search
        if name in subfolders or name in filenames:
            return os.path.abspath(os.path.join(foldername, name))
    return None


Modules_to_instaciate_build_dir = ["wishbone2iob"]

# need to be run with the build dir name
if len(sys.argv) >= 2:
    build_dir_name = sys.argv[1]
    print(build_dir_name)
else:
    print("Please provide two arguments.")
    sys.exit(1)  # Exiting with a non-zero code signifies an error condition
build_dir_caravel_path = None
current_dir = os.getcwd()  # gets current directory
CARAVEL_source_path = search_file_iname(
    current_dir, "CARAVEL"
)  # gets the submodule path
build_dir_path = search_file_iname(
    os.path.dirname(current_dir), os.path.basename(build_dir_name)
)  # gets the full path to the build dir
if os.path.exists(str(build_dir_path)):
    build_dir_caravel_path = os.path.join(
        build_dir_path, "CARAVEL"
    )  # get the new $Build_dir_path/CARAVEL path
    # copy CARAVEL submodule to build dir
    try:
        # Ensure that the source directory exists
        if os.path.exists(str(build_dir_path)):
            # Check if the target directory already exists
            if not os.path.exists(build_dir_caravel_path):
                shutil.copytree(CARAVEL_source_path, build_dir_caravel_path)
                print(
                    f"Directory '{CARAVEL_source_path}' copied to '{build_dir_caravel_path}'"
                )
            else:
                print(f"Directory '{build_dir_directory}' already exists.")
        else:
            print(f"Source directory '{build_dir_path}' does not exist.")
    except shutil.Error as e:
        print(f"Error: {e}")
    except OSError as e:
        print(f"Error: {e}")
    Top_path = search_file_iname(current_dir, "iob_caravel.v")  # gets the top_module
    source_path_caravel = os.path.join(
        os.path.dirname(search_file_iname(build_dir_caravel_path, "defines.v")),
        "iob_caravel.v",
    )
    open_lane_dir = search_file_iname(build_dir_caravel_path, "openlane")
    user_proj_example_dir = search_file_iname(
        build_dir_caravel_path, "user_proj_example"
    )
    New_top_module_dir = os.path.join(open_lane_dir, "iob_caravel")
    shutil.copyfile(
        Top_path, source_path_caravel
    )  # copy the top.v to the source of the verilog

    #automatic isntatitiation in the top dir
    iob_soc_src_path = os.path.join(build_dir_path, "hardware", "src")

    for _required_mod in Modules_to_instaciate_build_dir:
        a = 0







    # copy the required modules
    required_modules = []
    temporary_models = []
    temporary_models2 = []
    temporary_models3 = []
    if not os.path.exists(New_top_module_dir):
        os.makedirs(New_top_module_dir)
        print(f"Directory '{New_top_module_dir}' created.")
        # Copy contents of user_proj_example to temporary_dir
        for item in os.listdir(user_proj_example_dir):
            s = os.path.join(user_proj_example_dir, item)
            d = os.path.join(New_top_module_dir, item)
            if os.path.isdir(s):
                shutil.copytree(s, d, symlinks=True)
            else:
                shutil.copy2(s, d)

    iob_soc_src_path = os.path.join(build_dir_path, "hardware", "src")
    temporary_models = find_module_instantiations(source_path_caravel)
    required_modules = temporary_models + find_includes_vh(source_path_caravel)
    while temporary_models != []:
        temporary_models3 = []
        for verilog_names in temporary_models:
            destination_file_path = os.path.join(iob_soc_src_path, verilog_names)
            # search any new instatiated module in the verilog file
            temporary_models2 = find_module_instantiations(
                destination_file_path
            ) + find_includes_vh(destination_file_path)
            # verify if there is any repeated modules
            for verilog_names2 in temporary_models2:
                for verilog_names3 in required_modules:
                    if verilog_names2 == verilog_names3:
                        temporary_models2.remove(verilog_names2)
            temporary_models3 = temporary_models3 + temporary_models2
            required_modules = required_modules + temporary_models2
        temporary_models = temporary_models3

    # alters the json file to include the json
    json_temp = os.path.join(New_top_module_dir, "config.json")
    if os.path.exists(json_temp):
        with open(json_temp, "r") as json_file:
            data = json.load(json_file)
            data["DESIGN_NAME"] = "iob_caravel"
            data["VERILOG_FILES"] = [
                file
                for file in data["VERILOG_FILES"]
                if "user_proj_example.v" not in file
            ]
            data["VERILOG_FILES"].append(source_path_caravel)
            for verig in required_modules:
                temp = os.path.join(iob_soc_src_path, verig)
                data["VERILOG_FILES"].append(temp)
            # Add or modify the SYNTH_BUFFERING entry
            data["SYNTH_BUFFERING"] = 1
        with open(json_temp, "w") as json_file:
            json.dump(data, json_file, indent=4)
