package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
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
	"github.com/google/generative-ai-go/genai"
	"github.com/sashabaranov/go-openai"
	"golang.org/x/term"
	"google.golang.org/api/option"
)

type Config struct {
	Provider      string `json:"provider"`
	Model         string `json:"model"`
	APIKey        string `json:"api_key"`
	DefaultLength string `json:"default_length"`
}

var providers = []string{"gemini", "openai"}
var models = map[string][]string{
	"gemini": {"gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash"},
	"openai": {"gpt-5", "gpt-5-mini", "gpt-5-nano", "gpt-4.1"},
}

// Global color definitions
var (
	welcomeColor = color.New(color.FgCyan, color.Bold)
	choiceColor  = color.New(color.FgYellow)
	errorColor   = color.New(color.FgRed)
	successColor = color.New(color.FgGreen)
	queryColor   = color.New(color.FgCyan, color.Bold)
	responseColor = color.New(color.FgGreen)
	usageColor   = color.New(color.FgYellow)
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
func promptAndValidateAPIKey(reader *bufio.Reader, provider string) string {
	for {
		fmt.Printf("Enter your %s API key: ", strings.Title(provider))
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
		testConfig := &Config{Provider: provider, APIKey: apiKey}
		err = validateAPIKey(testConfig)
		s.Stop()
		if err != nil {
			errorColor.Println("Invalid API key. Please try again.")
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

	welcomeColor.Println("Welcome to q setup!")
	fmt.Println()

	// Load existing config if available
	existingConfig, err := loadConfig()
	if err != nil {
		existingConfig = &Config{Provider: "gemini", Model: "gemini-2.0-flash", DefaultLength: "medium", APIKey: ""}
	}

	// Choose provider
	choiceColor.Printf("Current provider: %s\n", strings.Title(existingConfig.Provider))
	fmt.Println("Choose your AI provider:")
	for i, p := range providers {
		fmt.Printf("  %d. %s\n", i+1, strings.Title(p))
	}
	fmt.Printf("  %d. Skip (keep current)\n", len(providers)+1)
	prompt := fmt.Sprintf("Enter choice (1-%d): ", len(providers)+1)
	choice := getValidatedChoice(reader, append(providers, "skip"), prompt)
	provider := existingConfig.Provider
	if choice <= len(providers) {
		provider = providers[choice-1]
	}
	printSuccess(fmt.Sprintf("Chosen provider: %s", strings.Title(provider)))
	fmt.Println()

	// Get available models for the provider
	modelsForProvider := models[provider]

	// Choose model
	choiceColor.Printf("Current model: %s\n", existingConfig.Model)
	fmt.Println("Available models:")
	for i, m := range modelsForProvider {
		fmt.Printf("  %d. %s\n", i+1, m)
	}
	fmt.Printf("  %d. Skip (keep current)\n", len(modelsForProvider)+1)
	prompt = fmt.Sprintf("Enter choice (1-%d): ", len(modelsForProvider)+1)
	choice = getValidatedChoice(reader, append(modelsForProvider, "skip"), prompt)
	model := existingConfig.Model
	if choice <= len(modelsForProvider) {
		model = modelsForProvider[choice-1]
	}
	printSuccess(fmt.Sprintf("Chosen model: %s", model))
	fmt.Println()

	// Choose default length
	choiceColor.Printf("Current default length: %s\n", strings.Title(existingConfig.DefaultLength))
	fmt.Println("Choose default response length:")
	fmt.Println("  1. Tiny (short responses)")
	fmt.Println("  2. Medium (balanced)")
	fmt.Println("  3. Large (detailed responses)")
	fmt.Println("  4. Skip (keep current)")
	prompt = "Enter choice (1-4): "
	choice = getValidatedChoice(reader, []string{"tiny", "medium", "large", "skip"}, prompt)
	defaultLength := existingConfig.DefaultLength
	if choice < 4 {
		switch choice {
		case 1:
			defaultLength = "tiny"
		case 2:
			defaultLength = "medium"
		case 3:
			defaultLength = "large"
		}
	}
	printSuccess(fmt.Sprintf("Chosen default length: %s", strings.Title(defaultLength)))
	fmt.Println()

	// Enter API key
	var apiKey string
	if existingConfig.APIKey != "" {
		choiceColor.Printf("Current API key: %s\n", maskKey(existingConfig.APIKey))
		fmt.Println("API Key:")
		fmt.Println("  1. Enter new API key")
		fmt.Println("  2. Skip (keep current)")
		prompt = "Enter choice (1-2): "
		choice = getValidatedChoice(reader, []string{"new", "skip"}, prompt)
		if choice == 2 {
			apiKey = existingConfig.APIKey
		} else {
			apiKey = promptAndValidateAPIKey(reader, provider)
		}
	} else {
		apiKey = promptAndValidateAPIKey(reader, provider)
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

func queryAI(config *Config, query string, maxTokens int, wordLimit int) (string, error) {
	switch config.Provider {
	case "gemini":
		return queryGemini(config.APIKey, config.Model, query, maxTokens, wordLimit)
	case "openai":
		return queryOpenAI(config.APIKey, config.Model, query, maxTokens, wordLimit)
	default:
		return "", fmt.Errorf("unsupported provider")
	}
}

func validateAPIKey(config *Config) error {
	testQuery := "Hello"
	_, err := queryAI(config, testQuery, 50, 50)
	if err != nil {
		return fmt.Errorf("API key validation failed: %v. Please run setup again with -S to update your key", err)
	}
	return nil
}

func queryGemini(apiKey, model, query string, maxTokens int, wordLimit int) (string, error) {
	if geminiClient == nil {
		ctx := context.Background()
		var err error
		geminiClient, err = genai.NewClient(ctx, option.WithAPIKey(apiKey))
		if err != nil {
			return "", err
		}
	}
	prompt := fmt.Sprintf("%s Please limit your response to approximately %d words.", query, wordLimit)
	m := geminiClient.GenerativeModel(model)
	max := int32(maxTokens)
	m.GenerationConfig.MaxOutputTokens = &max
	resp, err := m.GenerateContent(context.Background(), genai.Text(prompt))
	if err != nil {
		return "", err
	}

	if len(resp.Candidates) > 0 && len(resp.Candidates[0].Content.Parts) > 0 {
		return fmt.Sprintf("%v", resp.Candidates[0].Content.Parts[0]), nil
	}
	return "", fmt.Errorf("no response")
}

func queryOpenAI(apiKey, model, query string, maxTokens int, wordLimit int) (string, error) {
	if openaiClient == nil {
		openaiClient = openai.NewClient(apiKey)
	}
	prompt := fmt.Sprintf("%s Please limit your response to approximately %d words.", query, wordLimit)
	resp, err := openaiClient.CreateChatCompletion(
		context.Background(),
		openai.ChatCompletionRequest{
			Model:     model,
			Messages:  []openai.ChatCompletionMessage{{Role: openai.ChatMessageRoleUser, Content: prompt}},
			MaxTokens: maxTokens,
		},
	)
	if err != nil {
		return "", err
	}
	if len(resp.Choices) > 0 {
		return resp.Choices[0].Message.Content, nil
	}
	return "", fmt.Errorf("no response")
}

func printHelp() {
	fmt.Println("q - A command-line AI assistant")
	fmt.Println()
	fmt.Println("Usage:")
	fmt.Printf("  %s [flags] [query]\n", os.Args[0])
	fmt.Println()
	fmt.Println("Flags:")
	fmt.Println("  -h, -H, -help      Show help")
	fmt.Println("  -S, -s, -setup     Run setup to configure preferences")
	fmt.Println("  -t, -T, -tiny      Keep responses short")
	fmt.Println("  -m, -M, -medium    Keep responses medium")
	fmt.Println("  -l, -L, -large     Keep responses large")
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Printf("  %s -S\n", os.Args[0])
	fmt.Printf("  %s What is the capital of India?\n", os.Args[0])
	fmt.Printf("  %s -l Explain the importance of public transport in detail.\n", os.Args[0])
}

func main() {
	var setup bool
	var help bool
	var tiny bool
	var medium bool
	var large bool

	// Define flags with aliases using a map
	flagAliases := map[string]*bool{
		"S":     &setup,
		"setup": &setup,
		"s":     &setup,
		"H":     &help,
		"help":  &help,
		"h":     &help,
		"t":     &tiny,
		"T":     &tiny,
		"tiny":  &tiny,
		"m":     &medium,
		"M":     &medium,
		"medium": &medium,
		"l":     &large,
		"L":     &large,
		"large": &large,
	}

	for alias, varPtr := range flagAliases {
		var desc string
		switch varPtr {
		case &setup:
			desc = "Run setup to configure preferences"
		case &help:
			desc = "Show help"
		case &tiny:
			desc = "Keep responses short"
		case &medium:
			desc = "Keep responses medium"
		case &large:
			desc = "Keep responses large"
		}
		flag.BoolVar(varPtr, alias, false, desc)
	}

	flag.Usage = printHelp
	flag.Parse()

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
			fmt.Println("No configuration found. Run with -S to setup.")
			os.Exit(1)
		}
	}

	// Determine max tokens based on config default and flags
	var maxTokens int
	var wordLimit int
	if tiny {
		maxTokens = 300
		wordLimit = 200
	} else if medium {
		maxTokens = 1000
		wordLimit = 600
	} else if large {
		maxTokens = 2000
		wordLimit = 1000
	} else {
		// Use default from config
		switch config.DefaultLength {
		case "tiny":
			maxTokens = 300
			wordLimit = 200
		case "large":
			maxTokens = 2000
			wordLimit = 1000
		default:
			maxTokens = 1000
			wordLimit = 600
		}
	}

	args := flag.Args()
	if len(args) == 0 {
		usageColor.Printf("Usage: %s [flags] [query]\n", os.Args[0])
		os.Exit(1)
	}

	query := strings.Join(args, " ")

	s := spinner.New(spinner.CharSets[14], 100*time.Millisecond)
	s.Start()

	// Start timer goroutine
	go func() {
		seconds := 0
		s.Suffix = fmt.Sprintf(" Getting the answer... [%ds]", seconds)
		for {
			select {
			case <-time.After(1 * time.Second):
				seconds++
				s.Suffix = fmt.Sprintf(" Getting the answer... [%ds]", seconds)
			}
		}
	}()

	response, err := queryAI(config, query, maxTokens, wordLimit)
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
}