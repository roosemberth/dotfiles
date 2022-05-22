use serde::{Deserialize, Serialize};
use simpleini::{Ini, IniSection};
use std::env;
use std::fs;
use std::io::{Error, ErrorKind};
use std::os::unix::io::AsRawFd;
use std::path::Path;
use std::process::Command;

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

fn path_to_escaped(path: &Path) -> Result<String, std::io::Error> {
    String::from_utf8(
        Command::new("systemd-escape")
            .arg("-p")
            .arg(path)
            .output()?
            .stdout,
    )
    .map(|s| s.trim().to_owned())
    .map_err(|e| Error::new(ErrorKind::Other, e))
}

fn write_unit(ts: &TreeSpec, units_dir: &Path, subvol: &Path) -> Result<(), std::io::Error> {
    let name = subvol
        .file_name()
        .unwrap()
        .to_str()
        .unwrap()
        .strip_prefix("@")
        .unwrap();
    let adjusted = subvol.parent().unwrap().join(name);
    let subpath = adjusted.strip_prefix(&ts.layout_tree).unwrap();
    let what_ = Path::new(&ts.device_path);
    let where_ = Path::new(&ts.destination).join(subpath);
    let subvol_in_dev = Path::new("/").join(subvol.strip_prefix(&ts.tree_prefix).unwrap());

    let mut opts = Vec::new();
    opts.push(format!("subvol={}", subvol_in_dev.to_str().unwrap()));
    opts.extend_from_slice(&ts.extra_opts);

    let mut unit_section = IniSection::new("Unit");
    unit_section.set("Documentation", "See user-mounts-generator.");
    unit_section.set("Before", "local-fs.target");
    unit_section.set("After", format!("blockdev@{}", path_to_escaped(what_)?));

    let mut mount_section = IniSection::new("Mount");
    mount_section.set("What", what_.to_str().unwrap());
    mount_section.set("Where", where_.to_str().unwrap());
    mount_section.set("Type", "btrfs");
    mount_section.set("Options", opts.join(","));

    let mut ini = Ini::new();
    ini.add_section(unit_section);
    ini.add_section(mount_section);

    let unit_name = format!("{}.mount", path_to_escaped(&where_)?);
    let unit_path = units_dir.join(unit_name.clone());
    ini.to_file(&unit_path).map_err(|e| {
        Error::new(
            ErrorKind::Other,
            format!("Could not write {}: {}", unit_path.to_str().unwrap(), e),
        )
    })?;
    let install_dir = units_dir.join("local-fs.target.wants");
    fs::create_dir_all(&install_dir)?;
    symlink::symlink_file(format!("../{}", unit_name), install_dir.join(unit_name))?;

    Ok(())
}

fn write_units(units_dir: &str, ts: &TreeSpec) -> Result<(), std::io::Error> {
    println!("Scanning layout tree {}.", &ts.layout_tree);
    subvols_from_layout_tree(Path::new(&ts.layout_tree))?
        .iter()
        .try_for_each(move |sv| write_unit(&ts, Path::new(units_dir), sv))
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

fn setup_logging() -> Result<(), nix::Error> {
    if let Ok(kmsg) = fs::File::options().append(true).open("/dev/kmsg") {
        println!("Logging to /dev/kmsg.");
        let kmsg_fd = kmsg.as_raw_fd();
        nix::unistd::dup2(kmsg_fd, std::io::stdout().as_raw_fd())?;
        nix::unistd::dup2(kmsg_fd, std::io::stderr().as_raw_fd())?;
        println!("{} is now logging to kmsg.", env::args().next().unwrap());
    }
    Ok(())
}

fn main() -> Result<(), std::io::Error> {
    setup_logging().map_err(|e| {
        Error::new(
            ErrorKind::Other,
            format!("Could not setup logging to kmsg: {}", e),
        )
    })?;

    match &env::args().collect::<Vec<String>>()[1..] {
        [s] if s == "--help" => show_help(),
        [a, _b, _c] => do_work(a),
        _ => Ok(println!("Run with --help to show help message.")),
    }
}
