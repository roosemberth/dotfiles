use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::io::{Error, ErrorKind};
use std::path::Path;

const CFG_PATH_ENVVAR: &str = "USER_MOUNTS_GENERATOR_CONFIG";
const DEF_CFG_PATH: &str = "/etc/user-mounts.yaml";

#[derive(Debug, PartialEq, Serialize, Deserialize)]
struct TreeSpec {
    layout_tree: String,
    tree_prefix: String,
    destination: String,
    device_path: String,
    extra_opts: Vec<String>,
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
#[serde(transparent)]
struct ConfigFileSpec {
    trees: Vec<TreeSpec>,
}

fn show_help() -> Result<(), std::io::Error> {
    panic!("Help not implemented :(");
}

fn subvols_from_layout_tree(path: &Path) -> Result<Vec<Box<Path>>, std::io::Error> {
    fs::read_dir(path)?.try_fold(Vec::<Box<Path>>::new(), |mut paths, e| {
        let e = e?;
        if e.file_type()?.is_dir() {
            let name = e.file_name().to_str().unwrap().to_owned();
            let subpath = path.join(name.to_owned());
            match name.strip_prefix("@") {
                Some(_) => paths.push(subpath.into_boxed_path()),
                None => paths.append(&mut subvols_from_layout_tree(&subpath)?),
            }
        }
        Ok(paths)
    })
}

fn write_units(units_dir: &str, ts: &TreeSpec) -> Result<(), std::io::Error> {
    let subvols = subvols_from_layout_tree(Path::new(&ts.layout_tree))?;
    panic!(
        "Should be writing units from {:#?} to {:#?} but this is not implemented",
        subvols, units_dir
    )
}

fn do_work(units_dir: &str) -> Result<(), std::io::Error> {
    let cfg_file = env::var(CFG_PATH_ENVVAR).unwrap_or(DEF_CFG_PATH.to_owned());
    let cfg_lines: String = fs::read_to_string(cfg_file)?;
    let cfg: ConfigFileSpec = serde_yaml::from_str(&cfg_lines).map_err(|e| {
        Error::new(
            ErrorKind::InvalidData,
            format!("Could not read configuration file: {}", e),
        )
    })?;

    cfg.trees
        .iter()
        .try_for_each(|ts| write_units(units_dir, ts))
}

fn main() -> Result<(), std::io::Error> {
    match &env::args().collect::<Vec<String>>()[1..] {
        [s] if s == "--help" => show_help(),
        [a, _b, _c] => do_work(a),
        _ => Ok(println!("Run with --help to show help message.")),
    }
}
