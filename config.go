package main

type Config struct {
	// The service address.
	Address string `split_words:"true" default:":9090"`

	// The "Auth Domain" unique to your Cloudflare Access account.
	AuthDomain string `split_words:"true" required:"true"`
	// A list of allowed "Cloudflare Access - Application Audience (AUD)" tags.
	AllowedApplicationAudiences []string `split_words:"true" required:"true"`

	// Options: debug, info, warn, error, dpanic, panic, and fatal.
	LogLevel string `split_words:"true" default:"info"`

	// Set during build / compile time.
	Version string `split_words:"true" default:"unknown"`
}
