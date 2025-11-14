# q

A fast, minimalistc, and powerful command-line AI assistant that brings the power of LLMs directly to your terminal. Just BYOK (Bring Your Own Key) and get started. 

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

## Install, Update & Uninstall

### Quick Method (Recommended)

#### Linux/macOS

```bash
curl -fsSL https://raw.githubusercontent.com/atharva-again/q/main/install.sh | bash
```

#### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/atharva-again/q/main/install.ps1 | iex
```

This will:
- Download the appropriate binary for your system if none exists
- Install it to your PATH
- If an installation exists, it will ask you whether to update or uninstall


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

## Usage

### Basic Query

```bash
q What is the capital of India?
```

### Response Length Options

```bash
# Short responses
q Explain quantum computing -t

# Medium responses (default)
q -m How does photosynthesis work? -m

# Detailed responses
q Write a comprehensive guide to Docker -l
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
- `gemini-2.5-flash` 
- `gemini-2.5-pro` 
- `gemini-2.0-flash` 
- `gemini-2.5-flash-lite`
- `gemini-2.0-flash-lite`

### OpenAI
- `gpt-5` 
- `gpt-5-mini` 
- `gpt-5-nano` 
- `gpt-4.1`

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
