# q - Command-Line AI Assistant

A simple, fast CLI tool to query AI models (Gemini and OpenAI) directly from your terminal.

## Features

- Query Gemini (Google) or OpenAI models
- Cross-platform binaries for Linux, macOS, and Windows
- One-command installation with auto-setup
- Configurable response lengths (tiny, medium, large)

## Installation

### Linux/macOS
Run this one-liner in your terminal:
```bash
curl -fsSL https://raw.githubusercontent.com/atharva-again/q/main/install.sh | bash
```

### Windows
Run this in PowerShell:
```powershell
powershell -c "irm https://raw.githubusercontent.com/atharva-again/q/main/install.ps1 | iex"
```

The installer will:
- Download the correct binary for your OS/arch
- Install it to a system bin directory
- Add it to your PATH
- Run initial setup to configure your API keys

## Usage

After installation, use `q` to query AI:

```bash
q What is the capital of India?
q -l Explain the importance of public transport in detail.
q -S  # Run setup to change config
```

### Flags
- `-h, -help`: Show help
- `-S, -setup`: Run configuration setup
- `-t, -tiny`: Short responses
- `-m, -medium`: Balanced responses (default)
- `-l, -large`: Detailed responses

## Configuration

Setup stores config in:
- Linux/macOS: `~/.config/q/config.json`
- Windows: `%APPDATA%\q\config.json`

Supports Gemini and OpenAI providers with various models.

## Building from Source

If you want to build yourself:

1. Clone the repo
2. `go mod tidy`
3. Run `go build -o ` to generate binaries for all platforms

Requires Go 1.21+, and UPX for compression.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

For feature requests or bug reports, please open an issue.

We welcome contributions! Here's how to get started:

1. **Fork the repository** on GitHub.
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes**: Ensure code is clean, well-documented, and follows Go conventions.
4. **Test thoroughly**: Run existing tests and add new ones if needed.
5. **Commit with clear messages**: Use descriptive commit messages.
6. **Submit a Pull Request**: Provide a clear description of your changes and why they're needed.
7. **Code Style**: Follow standard Go formatting (`go fmt`), and keep lines under 80 characters where possible.
8. **Respect the License**: All contributions are under the MIT License.
 
Contact: Atharva Verma <atharva.verma18@gmail.com>