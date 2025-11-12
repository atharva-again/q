# q

A fast, minimalistc, and powerful command-line AI assistant that brings the power of LLMs directly to your terminal.

<p align = "center">
  <img width="600" height="400" alt="An image demonstrating q CLI query." src="https://github.com/user-attachments/assets/7f00ae57-4c3b-40c4-967b-3dbb96a4e8db" />
  <img width="600" height="400" alt="An image demonstrating q CLI setup." src="https://github.com/user-attachments/assets/dd5e3785-407f-4d85-97c6-f85066e479ca" />
</p>

<p align = "center">
  <img width="45%" alt="An image demonstrating q CLI query with -t flag." src="https://github.com/user-attachments/assets/4290b748-00f4-44a5-842a-af541fb53a35" />
  <img width="45%" alt="An image demonstrating q CLI stats feature." src="https://github.com/user-attachments/assets/2fd5465f-c489-4480-ad91-7a8846528a41" />
</p>

## Features

- **Fast & Lightweight**: Minimal dependencies, quick responses
- **Beautiful Output**: Rich markdown rendering with syntax highlighting
- **Multiple AI Providers**: Support for Google Gemini and OpenAI models
- **Flexible Configuration**: Easy setup with interactive wizard
- **Response Control**: Choose response length (tiny, medium, large)
- **Cross-Platform**: Works on Linux, macOS, and Windows

## Installation

### Quick Install (Recommended)

#### Linux/macOS

```bash
curl -fsSL https://raw.githubusercontent.com/atharva-again/q/main/install.sh | bash
```

#### Windows (PowerShell)

```powershell
iex "& { $(irm https://raw.githubusercontent.com/atharva-again/q/main/install.ps1) }"
```

This will:
- Download the appropriate binary for your system
- Install it to your PATH
- Run the initial setup wizard

### Manual Installation

1. Download the latest release from [GitHub Releases](https://github.com/atharva-again/q/releases)
2. Extract the archive
3. Move the binary to a directory in your PATH
4. Run `q -S` to configure

### Setup & Configuration

Run setup to configure your AI provider and preferences:

```bash
q -S
```

This will guide you through:
- Choosing your AI provider (Gemini/OpenAI)
- Selecting a model
- Setting default response length
- Entering your API key

You can find API keys here:
- [Google AI Studio](https://aistudio.google.com/) (for Gemini models)
- [OpenAI API Keys](https://platform.openai.com/account/api-keys)

### Build from Source

```bash
git clone https://github.com/atharva-again/q.git
cd q
go build -o q .
sudo mv q /usr/local/bin/
q -S
```

## Update q

To update to the latest version, run:

### For Linux/macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/atharva-again/q/main/install.sh | bash --update
```

### For Windows (PowerShell):

```powershell
iex "& { $(irm https://raw.githubusercontent.com/atharva-again/q/main/install.ps1) } -Action update"
```

## Uninstall q

To uninstall q, run:

### For Linux/macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/atharva-again/q/main/install.sh | bash --uninstall
```

### For Windows (PowerShell):

```powershell 
iex "& { $(irm https://raw.githubusercontent.com/atharva-again/q/main/install.ps1) } -Action uninstall"
```

## Usage

### Basic Query

```bash
q "What is the capital of India?"
```

### Response Length Options

```bash
# Short responses
q -t "Explain quantum computing"

# Medium responses (default)
q -m "How does photosynthesis work?"

# Detailed responses
q -l "Write a comprehensive guide to Docker"
```

### Help

```bash
q -h  # Show help
q -S  # Run setup
```

## Configuration

Configuration is stored in:
- Linux/macOS: `~/.config/q/config.json`
- Windows: `%APPDATA%\q\config.json`

Example config:
```json
{
  "provider": "gemini",
  "model": "gemini-2.0-flash",
  "api_key": "your-api-key-here",
  "default_length": "medium"
}
```

## Supported Models

### Google Gemini
- `gemini-2.5-flash` (Fast, recommended)
- `gemini-2.5-pro` (Most capable)
- `gemini-2.0-flash` (Legacy)

### OpenAI
- `gpt-5` (Latest GPT-5)
- `gpt-5-mini` (Fast, cost-effective)
- `gpt-5-nano` (Fastest, cheapest)
- `gpt-4.1` (Legacy GPT-4.1)

## Examples

```bash
# Quick facts
q "What is the population of Tokyo?"

# Code explanations
q "Explain how recursion works in Python"

# Creative writing
q -l "Write a short story about a robot learning emotions"

# Technical questions
q "How do I optimize a PostgreSQL query?"

# Learning
q -m "Explain the concept of containerization"
```

## Development

### Prerequisites

- Go 1.25.4 or later
- Git

### Building

```bash
# Build for current platform
go build -o q .

# Build for multiple platforms
./build.sh
```

### Testing

```bash
go test ./...
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Atharva Verma** - [atharva.verma18@gmail.com](mailto:atharva.verma18@gmail.com)
