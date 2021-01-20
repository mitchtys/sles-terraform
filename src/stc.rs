// TODO: Get this main() stuff into src/cli.rs via src/lib.rs and just call that in main()

fn main() {
    let stc_version_verbose = format!(
        "{} arch {} built on {} commit {}\n",
        concat!("version ", clap::crate_version!()),
        env!("VERGEN_TARGET_TRIPLE"),
        env!("VERGEN_BUILD_TIMESTAMP"),
        env!("VERGEN_SHA_SHORT")
    );

    let mut out = std::io::stdout();
    let mut app = clap::App::new("stc")
        .version(clap::crate_version!())
        .long_version(&stc_version_verbose[..])
        .setting(clap::AppSettings::TrailingVarArg)
        .setting(clap::AppSettings::UnifiedHelpMessage)
        .setting(clap::AppSettings::ArgRequiredElseHelp)
        .about("Suse Terraform Cli ...ish todo: pick a better name");

    let matches = app.clone().get_matches_safe();

    // Ignore the parse error on no args for now, this match setup is only
    // because I've no args or subcommands which is abnormal actually.
    if let Err(e) = matches {
        match e.kind {
            clap::ErrorKind::MissingArgumentOrSubcommand => {
                println!("hi");
                std::process::exit(0);
            }
            clap::ErrorKind::VersionDisplayed => {
                std::process::exit(0);
            }
            clap::ErrorKind::HelpDisplayed => {
                app.write_long_help(&mut out)
                    .expect("couldn't write help to stdout?");
                std::process::exit(0);
            }
            clap::ErrorKind::UnknownArgument => {
                eprintln!("{}", e.message);
                std::process::exit(1);
            }
            _ => {
                eprintln!("You shouldn't have gotten here... probably a bug");
                dbg!(e);
                std::process::exit(1);
            }
        }
    }
    app.write_long_help(&mut out)
        .expect("couldn't write help to stdout?");
}
