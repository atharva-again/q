package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/user"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/briandowns/spinner"
	"github.com/charmbracelet/glamour"
	"github.com/fatih/color"
	"github.com/sashabaranov/go-openai"
	"golang.org/x/term"
	"golang.org/x/text/cases"
	"golang.org/x/text/language"
	"google.golang.org/genai"
)

// Version of the q CLI tool. Set via build flags: go build -ldflags "-X main.Version=v1.1.0"
var Version = "v1.1.0"

const asciiArt = `

  /$$$$$$ 
 /$$__  $$
| $$  \ $$
| $$  | $$
|  $$$$$$$
 \____  $$
      | $$
      | $$
      |__/
`

type Config struct {
	Provider      string `json:"provider"`
	Model         string `json:"model"`
	APIKey        string `json:"api_key"`
	DefaultLength string `json:"default_length"`
}

var providers = []string{"gemini", "openai"}
var models = map[string][]string{
	"gemini": {"gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash", "gemini-2.0-flash-lite", "gemini-2.5-flash-lite"},
	"openai": {"gpt-5", "gpt-5-mini", "gpt-5-nano", "gpt-4.1"},
}

// Global color definitions
var (
	welcomeColor  = color.New(color.FgCyan, color.Bold)
	choiceColor   = color.New(color.FgYellow)
	errorColor    = color.New(color.FgRed)
	successColor  = color.New(color.FgGreen)
	queryColor    = color.New(color.FgCyan, color.Bold)
	responseColor = color.New(color.FgGreen)
	usageColor    = color.New(color.FgYellow)
)

// Global API clients for reuse
var (
	geminiClient *genai.Client
	openaiClient *openai.Client
)

func maskKey(key string) string {
	if len(key) <= 4 {
		return strings.Repeat("*", len(key))
	}
	return strings.Repeat("*", len(key)-4) + key[len(key)-4:]
}

func getConfigPath() string {
	var configDir string
	if runtime.GOOS == "windows" {
		// Use %APPDATA% on Windows
		appData := os.Getenv("APPDATA")
		if appData == "" {
			appData = filepath.Join(os.Getenv("USERPROFILE"), "AppData", "Roaming")
		}
		configDir = filepath.Join(appData, "q")
	} else {
		// Use ~/.config on Unix-like systems (Linux, macOS)
		usr, _ := user.Current()
		configDir = filepath.Join(usr.HomeDir, ".config", "q")
	}
	return filepath.Join(configDir, "config.json")
}

func loadConfig() (*Config, error) {
	path := getConfigPath()
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	var config Config
	err = json.NewDecoder(file).Decode(&config)
	return &config, err
}

func saveConfig(config *Config) error {
	path := getConfigPath()
	dir := filepath.Dir(path)
	os.MkdirAll(dir, 0755)
	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()
	return json.NewEncoder(file).Encode(config)
}

// Helper for validated choice input
func getValidatedChoice(reader *bufio.Reader, options []string, prompt string) int {
	fmt.Print(prompt)
	input, _ := reader.ReadString('\n')
	input = strings.TrimSpace(input)
	choice, err := strconv.Atoi(input)
	if err != nil || choice < 1 || choice > len(options) {
		errorColor.Println("Invalid choice. Exiting.")
		os.Exit(1)
	}
	return choice
}

// Helper for API key prompting and validation
func promptAndValidateAPIKey(reader *bufio.Reader, provider string, model string) string {
	titleCaser := cases.Title(language.Und)
	for {
		fmt.Printf("Enter your %s API key: ", titleCaser.String(provider))
		apiKeyBytes, err := term.ReadPassword(int(os.Stdin.Fd()))
		if err != nil {
			log.Fatal("Failed to read API key:", err)
		}
		apiKey := string(apiKeyBytes)
		fmt.Println() // Move to next line after hidden input

		// Validate API key with spinner
		s := spinner.New(spinner.CharSets[14], 100*time.Millisecond)
		s.Suffix = " Validating API key..."
		s.Start()
		testConfig := &Config{Provider: provider, Model: model, APIKey: apiKey}
		err = validateAPIKey(testConfig)
		s.Stop()
		if err != nil {
			errorColor.Println("Invalid API key. Please try again.")
			fmt.Printf("Your entered API key: %s\n", maskKey(apiKey))
			continue
		}
		return apiKey
	}
}

// Helper for success messages
func printSuccess(message string) {
	successColor.Println(message)
}

func runSetup() *Config {
	reader := bufio.NewReader(os.Stdin)

	fmt.Print(asciiArt)
	fmt.Println()
	welcomeColor.Println("Welcome to q setup!")
	fmt.Println()

	// Load existing config if available
	existingConfig, err := loadConfig()
	if err != nil {
		existingConfig = nil // No defaults if config missing
	}

	// Choose provider
	var provider string
	titleCaser := cases.Title(language.Und)
	if existingConfig != nil {
		choiceColor.Printf("Current provider: %s\n", titleCaser.String(existingConfig.Provider))
		fmt.Println("Provider:")
		fmt.Println("  1. Keep current")
		fmt.Println("  2. Choose new")
		choice := getValidatedChoice(reader, []string{"keep", "new"}, "Enter choice (1-2): ")
		if choice == 1 {
			provider = existingConfig.Provider
		} else {
			fmt.Println("Choose your AI provider:")
			for i, p := range providers {
				fmt.Printf("  %d. %s\n", i+1, titleCaser.String(p))
			}
			choice = getValidatedChoice(reader, providers, fmt.Sprintf("Enter choice (1-%d): ", len(providers)))
			provider = providers[choice-1]
		}
	} else {
		fmt.Println("Choose your AI provider:")
		for i, p := range providers {
			fmt.Printf("  %d. %s\n", i+1, titleCaser.String(p))
		}
		choice := getValidatedChoice(reader, providers, fmt.Sprintf("Enter choice (1-%d): ", len(providers)))
		provider = providers[choice-1]
	}
	printSuccess(fmt.Sprintf("Chosen provider: %s", titleCaser.String(provider)))
	fmt.Println()

	// Get available models for the provider
	modelsForProvider := models[provider]

	// Choose model
	var model string
	if existingConfig != nil && existingConfig.Provider == provider {
		choiceColor.Printf("Current model: %s\n", existingConfig.Model)
		fmt.Println("Model:")
		fmt.Println("  1. Keep current")
		fmt.Println("  2. Choose new")
		choice := getValidatedChoice(reader, []string{"keep", "new"}, "Enter choice (1-2): ")
		if choice == 1 {
			model = existingConfig.Model
		} else {
			fmt.Println("Available models:")
			for i, m := range modelsForProvider {
				fmt.Printf("  %d. %s\n", i+1, m)
			}
			choice = getValidatedChoice(reader, modelsForProvider, fmt.Sprintf("Enter choice (1-%d): ", len(modelsForProvider)))
			model = modelsForProvider[choice-1]
		}
	} else {
		fmt.Println("Available models:")
		for i, m := range modelsForProvider {
			fmt.Printf("  %d. %s\n", i+1, m)
		}
		choice := getValidatedChoice(reader, modelsForProvider, fmt.Sprintf("Enter choice (1-%d): ", len(modelsForProvider)))
		model = modelsForProvider[choice-1]
	}
	printSuccess(fmt.Sprintf("Chosen model: %s", model))
	fmt.Println()

	// Choose default length
	var defaultLength string
	lengthOptions := []string{"tiny", "medium", "large"}
	if existingConfig != nil {
		choiceColor.Printf("Current default length: %s\n", titleCaser.String(existingConfig.DefaultLength))
		fmt.Println("Default length:")
		fmt.Println("  1. Keep current")
		fmt.Println("  2. Choose new")
		choice := getValidatedChoice(reader, []string{"keep", "new"}, "Enter choice (1-2): ")
		if choice == 1 {
			defaultLength = existingConfig.DefaultLength
		} else {
			fmt.Println("Choose default response length:")
			fmt.Println("  1. Tiny (short responses)")
			fmt.Println("  2. Medium (balanced)")
			fmt.Println("  3. Large (detailed responses)")
			choice = getValidatedChoice(reader, lengthOptions, "Enter choice (1-3): ")
			defaultLength = lengthOptions[choice-1]
		}
	} else {
		fmt.Println("Choose default response length:")
		fmt.Println("  1. Tiny (short responses)")
		fmt.Println("  2. Medium (balanced)")
		fmt.Println("  3. Large (detailed responses)")
		choice := getValidatedChoice(reader, lengthOptions, "Enter choice (1-3): ")
		defaultLength = lengthOptions[choice-1]
	}
	printSuccess(fmt.Sprintf("Chosen default length: %s", titleCaser.String(defaultLength)))
	fmt.Println()

	// Enter API key
	var apiKey string
	if existingConfig != nil && existingConfig.APIKey != "" {
		choiceColor.Printf("Current API key: %s\n", maskKey(existingConfig.APIKey))
		fmt.Println("API key:")
		fmt.Println("  1. Keep current")
		fmt.Println("  2. Enter new")
		choice := getValidatedChoice(reader, []string{"keep", "new"}, "Enter choice (1-2): ")
		if choice == 1 {
			apiKey = existingConfig.APIKey
		} else {
			apiKey = promptAndValidateAPIKey(reader, provider, model)
		}
	} else {
		apiKey = promptAndValidateAPIKey(reader, provider, model)
	}

	printSuccess(fmt.Sprintf("API key set: %s", maskKey(apiKey)))

	config := &Config{Provider: provider, Model: model, APIKey: apiKey, DefaultLength: defaultLength}
	err = saveConfig(config)
	if err != nil {
		log.Fatal("Failed to save config:", err)
	}
	welcomeColor.Println("Setup complete!")
	return config
}

func queryAI(config *Config, query string, wordLimit int) (string, error) {
	switch config.Provider {
	case "gemini":
		return queryGemini(config.APIKey, config.Model, query, wordLimit)
	case "openai":
		return queryOpenAI(config.APIKey, config.Model, query, wordLimit)
	default:
		return "", fmt.Errorf("unsupported provider")
	}
}

func validateAPIKey(config *Config) error {
	testQuery := "Hello"
	_, err := queryAI(config, testQuery, 50)
	if err != nil {
		return fmt.Errorf("API key validation failed: %v. Please run setup again with -S to update your key", err)
	}
	return nil
}

func queryGemini(apiKey, model, query string, wordLimit int) (string, error) {
	ctx := context.Background()
	if geminiClient == nil {
		var err error
		geminiClient, err = genai.NewClient(ctx, &genai.ClientConfig{
			APIKey:  apiKey,
			Backend: genai.BackendGeminiAPI,
		})
		if err != nil {
			errorColor.Printf("Gemini API client creation failed: %v\n", err)
			return "", err
		}
	}
	prompt := fmt.Sprintf("You must provide a response that is approximately %d words long. Answer the following query in markdown format: %s", wordLimit, query)
	contents := []*genai.Content{{Parts: []*genai.Part{genai.NewPartFromText(prompt)}}}

	// Set thinking_budget=0 for Gemini 2.5 models to reduce latency
	var config *genai.GenerateContentConfig
	if strings.HasPrefix(model, "gemini-2.5-") {
		zero := int32(0)
		config = &genai.GenerateContentConfig{
			ThinkingConfig: &genai.ThinkingConfig{
				ThinkingBudget: &zero,
			},
		}
	}

	resp, err := geminiClient.Models.GenerateContent(ctx, model, contents, config)
	if err != nil {
		errorColor.Printf("Gemini API error: %v\n", err)
		errorColor.Printf("Gemini error type: %T, value: %v\n", err, err)
		return "", err
	}
	if len(resp.Candidates) > 0 && len(resp.Candidates[0].Content.Parts) > 0 {
		return resp.Candidates[0].Content.Parts[0].Text, nil
	}
	errorColor.Println("Gemini API returned no response candidates.")
	// Print candidate metadata for debugging
	if len(resp.Candidates) > 0 {
		fmt.Printf("Candidate metadata: %+v\n", resp.Candidates[0].Content)
	}
	return "", fmt.Errorf("no response")
}

func queryOpenAI(apiKey, model, query string, wordLimit int) (string, error) {
	if openaiClient == nil {
		openaiClient = openai.NewClient(apiKey)
	}
	prompt := fmt.Sprintf("You must provide a response that is approximately %d words long. Answer the following query in markdown format: %s", wordLimit, query)

	// Add reasoning.effort for reasoning models (gpt-5, gpt-5-mini, gpt-5-nano)
	reasoningEffort := ""
	switch model {
	case "gpt-5", "gpt-5-mini", "gpt-5-nano":
		reasoningEffort = "low" // Fastest response, lowest cost
	}

	// If using a reasoning model, use the Responses API (not supported in go-openai yet)
	// For now, just add a system message to simulate the effect
	var messages []openai.ChatCompletionMessage
	if reasoningEffort != "" {
		messages = []openai.ChatCompletionMessage{
			{Role: openai.ChatMessageRoleSystem, Content: "reasoning.effort: low"},
			{Role: openai.ChatMessageRoleUser, Content: prompt},
		}
	} else {
		messages = []openai.ChatCompletionMessage{{Role: openai.ChatMessageRoleUser, Content: prompt}}
	}

	resp, err := openaiClient.CreateChatCompletion(
		context.Background(),
		openai.ChatCompletionRequest{
			Model:    model,
			Messages: messages,
			// MaxTokens omitted
		},
	)
	if err != nil {
		errorColor.Printf("OpenAI API error: %v\n", err)
		// Print additional details if available
		if apiErr, ok := err.(*openai.APIError); ok {
			errorColor.Printf("OpenAI API error details: Type=%v, Message=%v, Code=%v\n", apiErr.Type, apiErr.Message, apiErr.Code)
		}
		return "", err
	}
	if len(resp.Choices) > 0 {
		return resp.Choices[0].Message.Content, nil
	}
	errorColor.Println("OpenAI API returned no response choices.")
	return "", fmt.Errorf("no response")
}

func printHelp() {
	fmt.Print(asciiArt)
	fmt.Println()
	welcomeColor.Println("q - A command-line AI assistant")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Printf("  %s [query] [flags]\n", os.Args[0])
	fmt.Println()
	fmt.Println("Flags:")
	fmt.Println("  -h, -H, -help      Show help")
	fmt.Println("  -v, -V, --version  Show version information")
	fmt.Println("  -S, -s, -setup     Run setup to configure preferences")
	fmt.Println("  -t, -T, -tiny      Keep responses short")
	fmt.Println("  -m, -M, -medium    Keep responses medium")
	fmt.Println("  -l, -L, -large     Keep responses large")
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Printf("  %s --version\n", os.Args[0])
	fmt.Printf("  %s What is the capital of India?\n", os.Args[0])
	fmt.Printf("  %s What is the role of Jack Dorsey in Twitter? -l\n", os.Args[0])
	fmt.Printf("  %s -S\n", os.Args[0])
}

func main() {
	var setup bool
	var help bool
	var tiny bool
	var medium bool
	var large bool
	var showVersion bool

	// Manual argument parsing to allow flags after query
	args := os.Args[1:]
	var queryParts []string
	for _, arg := range args {
		switch arg {
		case "-h", "-H", "-help":
			help = true
		case "-v", "-V", "--version":
			showVersion = true
		case "-S", "-s", "-setup":
			setup = true
		case "-t", "-T", "-tiny":
			tiny = true
		case "-m", "-M", "-medium":
			medium = true
		case "-l", "-L", "-large":
			large = true
		default:
			if strings.HasPrefix(arg, "-") {
				// Unknown flag, ignore or handle as needed
				continue
			}
			queryParts = append(queryParts, arg)
		}
	}

	if showVersion {
		fmt.Print(asciiArt)
		fmt.Println()
		fmt.Println(Version)
		os.Exit(0)
	}

	if help {
		printHelp()
		os.Exit(0)
	}

	var config *Config
	var err error

	if setup {
		config = runSetup()
	} else {
		config, err = loadConfig()
		if err != nil {
			usageColor.Println("No configuration found. Please run 'q -s' to setup before using q.")
			os.Exit(1)
		}
	}

	// Only use wordLimit
	var wordLimit int
	if tiny {
		wordLimit = 200
	} else if medium {
		wordLimit = 600
	} else if large {
		wordLimit = 1000
	} else {
		// Use default from config
		switch config.DefaultLength {
		case "tiny":
			wordLimit = 200
		case "large":
			wordLimit = 1000
		default:
			wordLimit = 600
		}
	}

	if len(queryParts) == 0 && !setup {
		usageColor.Printf("Usage: %s [query] [flags]\n", os.Args[0])
		os.Exit(1)
	}

	query := strings.Join(queryParts, " ")

	s := spinner.New(spinner.CharSets[14], 100*time.Millisecond)
	s.Start()

	// Start timer goroutine
	go func() {
		seconds := 0
		for {
			time.Sleep(1 * time.Second)
			seconds++
			s.Suffix = fmt.Sprintf(" Getting the answer... [%ds]", seconds)
		}
	}()

	if !setup {
		start := time.Now()
		response, err := queryAI(config, query, wordLimit)
		elapsed := time.Since(start)
		if err != nil {
			s.Stop()
			log.Fatal(err)
		}

		s.Stop()

		queryColor.Printf("Query: %s\n\n", query)
		responseColor.Println("Response:")

		r, _ := glamour.NewTermRenderer(
			glamour.WithAutoStyle(),
			glamour.WithWordWrap(80),
		)
		rendered, _ := r.Render(response)
		fmt.Print(rendered)

		// Print stats in muted italic
		muted := color.New(color.FgHiBlack, color.Italic)
		var size string
		switch wordLimit {
		case 200:
			size = "tiny"
		case 600:
			size = "medium"
		case 1000:
			size = "large"
		default:
			size = "custom"
		}
		muted.Printf("\nStats: Response generated in %.1f seconds using %s for %s response.\n", elapsed.Seconds(), config.Model, size)
	}
}
