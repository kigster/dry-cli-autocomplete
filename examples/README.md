# Examples

![Coverage](docs/img/badge.svg)

A small `dry-cli` app, `mycli`, adapted from the [dry-cli-ui](https://github.com/kigster/dry-cli-ui) examples, with a `completion` command added. Two commands show off the UI widgets; `completion` prints a shell completion script for all of them.

The Gemfile loads `dry-cli-autocomplete` from `../`, so the script is the one this checkout generates, not the last release.

First:

```bash
bundle install
```

## Help

```bash
$ bundle exec bin/mycli -h
mycli

Downloads URLs and finds hosts on the local network, several at once.

USAGE
  mycli COMMAND [OPTIONS]

COMMANDS
  version, v               Print version
  download-urls, download  Download URLs, each to its own file
  find-hosts, hosts        Find hosts on the local network that listen on
                           common TCP ports
  completion               Print a shell completion script

OPTIONS
  -h, --help               Show help
  -v, --version            Print version
```

## Completion

The script completes the program name `mycli`, so put `bin/` on `PATH` first:

```bash
export PATH="$PWD/bin:$PATH"
```

bash:

```bash
eval "$(mycli completion bash)"
```

zsh, after `compinit`:

```bash
eval "$(mycli completion zsh)"
```

Then `mycli <TAB>` offers the commands, `mycli find-hosts --p<TAB>` offers `--ports` and `--progress`, and `mycli completion <TAB>` offers `bash` and `zsh`.

## Commands to Try

- `download-urls URL1 URL2 ...` downloads each URL to its own file in the current folder, under a progress bar per URL.
- `download-urls -u urls.txt` reads the URLs from `urls.txt`, one per line, skipping blank lines and `#` comments. URLs given as arguments are downloaded too. Invalid URLs, from either place, are skipped and listed in a warning before the downloads start.
- `download-urls --spinner --output=downloads URL1 URL2 ...` shows a spinner per URL instead, and saves the files in `downloads/`, creating it when missing.
- `find-hosts` probes every address on the local /24 network on the common TCP ports, 10 addresses at a time, under two bars: one counts the addresses that answered, the other those that did not. It ends with a box listing each host that answered, its name when the resolver knows one (mDNS included), and its open ports.
- `find-hosts --spinner --output=hosts.txt` shows a spinner per address instead, and also writes the result to `hosts.txt`.
- `find-hosts --ports=22,80` probes only ports 22 and 80. `find-hosts --list` prints the common ports and what usually listens on each.
- `find-hosts --cidr=172.16.0.0/23` scans that network instead of the local one. A network of more than 1024 addresses is refused unless `--unlimited` (`-u`) is given.

Both commands show progress bars by default (`-p`), and `--spinner` (`-s`) switches to spinners. `--concurrency` (`-c`, or `--cpus`) sets how many URLs or addresses run at once, from 1 to 100.

A command that cannot go on, such as one given `--concurrency=0` or a `--cidr` that is not a network, prints the error and exits with status 1.

## File names

`download-urls` names each file after the URL's host, path and query, with anything unsafe replaced by `_`:

| URL                                                     | File                                            |
| ------------------------------------------------------- | ----------------------------------------------- |
| `https://www.ruby-lang.org/images/header-ruby-logo.png` | `www.ruby-lang.org_images_header-ruby-logo.png` |
| `https://example.com`                                   | `example.com.html`                              |
| `https://httpbin.org/json`                              | `httpbin.org_json.json`                         |

A file keeps the extension its URL path has. Without one, the extension comes from the response's `Content-Type`, and is `.txt` for a type the command does not know.

## Layout

`bin/mycli` puts `lib/` on the load path and calls `MyCLI::Launcher`. Zeitwerk loads the rest from `lib/`, one constant per file:

| Path                                           | What it does                                                                                                          |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `lib/mycli/launcher.rb`                        | Runs the CLI with the streams it is given, and turns the outcome into an exit status                                  |
| `lib/mycli/cli/help_settings.rb`               | The dry-cli-help settings                                                                                             |
| `lib/mycli/cli/commands.rb`                    | The registry: every command's name and aliases, and the `completion` command                                          |
| `lib/mycli/cli/commands/base.rb`               | What every command inherits: `ui` on the command's own streams, and `error!`                                          |
| `lib/mycli/cli/commands/concurrent_command.rb` | The parent of commands that run work concurrently: `--progress`, `--spinner`, `--concurrency`                         |
| `lib/mycli/cli/commands/*.rb`                  | A command each, plus the `Concurrency` and `DisplayOptions` mixins                                                    |
| `lib/mycli/cli/commands/download_urls/`        | `UrlList`, `FileName`, `Downloader` and `HTTP`, and the two displays                                                  |
| `lib/mycli/cli/commands/find_hosts/`           | `Subnet` (on `IPAddr`), `Scanner`, `PortProbe`, `HostName`, `FileLimit`, `WorkerPool`, `Report`, and the two displays |

A command reads its options and reports the outcome. The code that does its work lives under the command's own namespace, beside `ProgressDisplay` and `SpinnerDisplay`, which share an interface. Neither the work nor the display reads the command line.

## Tests

```bash
bundle exec rspec
```

`spec/` mirrors `lib/`, one spec per file. `spec/mycli/launcher_spec.rb` runs the executable in-process through Aruba. WebMock stands in for the network in the HTTP and download specs, and the scan specs stub the port probe.
