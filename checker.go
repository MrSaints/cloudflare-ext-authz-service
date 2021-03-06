package main

import (
	"context"
	"fmt"
	"net/http"

	"github.com/coreos/go-oidc"
	"go.uber.org/zap"
)

type checker interface {
	Check(ctx context.Context, req *Request) (*Response, error)
}

type cloudflareAuthChecker struct {
	verifier *oidc.IDTokenVerifier
	logger   *zap.Logger

	// The "Auth Domain" unique to your Cloudflare Access account.
	authDomain string
	// A list of allowed "Cloudflare Access - Application Audience (AUD)" tags.
	allowedApplicationAudiences []string
}

func NewCloudflareAuthChecker(ctx context.Context, authDomain string, allowedApplicationAudiences []string, logger *zap.Logger) *cloudflareAuthChecker {
	certsURL := fmt.Sprintf("%s/cdn-cgi/access/certs", authDomain)
	config := &oidc.Config{
		// We are checking it manually so that we can support multiple client IDs.
		SkipClientIDCheck: true,
	}
	keySet := oidc.NewRemoteKeySet(ctx, certsURL)
	verifier := oidc.NewVerifier(authDomain, keySet, config)
	return &cloudflareAuthChecker{
		verifier:                    verifier,
		logger:                      logger,
		authDomain:                  authDomain,
		allowedApplicationAudiences: allowedApplicationAudiences,
	}
}

// Based on https://developers.cloudflare.com/access/advanced-management/validating-json
func (c *cloudflareAuthChecker) Check(ctx context.Context, req *Request) (*Response, error) {
	c.logger.Info("Handling request", zap.String("url", req.Request.URL.String()))

	accessJWT := req.Request.Header.Get("Cf-Access-Jwt-Assertion")
	if accessJWT == "" {
		c.logger.Debug(
			"No Cloudflare Access header found",
			zap.String("authDomain", c.authDomain),
		)
		return &Response{
			Allow: false,
			Response: http.Response{
				StatusCode: http.StatusUnauthorized,
			},
		}, nil
	}

	if len(c.allowedApplicationAudiences) == 0 {
		c.logger.Warn(
			"No allowed application audiences set, denying all requests",
			zap.String("authDomain", c.authDomain),
		)
		return &Response{
			Allow: false,
			Response: http.Response{
				StatusCode: http.StatusUnauthorized,
			},
		}, nil
	}

	c.logger.Debug(
		"Verifying token",
		zap.String("authDomain", c.authDomain),
		zap.Strings("allowedApplicationAudiences", c.allowedApplicationAudiences),
		zap.Bool("hasAccessJWT", len(accessJWT) > 0),
	)

	idToken, err := c.verifier.Verify(ctx, accessJWT)
	if err != nil {
		c.logger.Debug(
			"Failed to verify token",
			zap.String("authDomain", c.authDomain),
			zap.Strings("allowedApplicationAudiences", c.allowedApplicationAudiences),
			zap.Error(err),
		)
		return &Response{
			Allow: false,
			Response: http.Response{
				StatusCode: http.StatusUnauthorized,
			},
		}, nil
	}

	for _, allowedApplicationAudience := range c.allowedApplicationAudiences {
		for _, audience := range idToken.Audience {
			if allowedApplicationAudience == audience {
				return &Response{
					Allow: true,
					Response: http.Response{
						StatusCode: http.StatusOK,
					},
				}, nil
			}
		}
	}

	c.logger.Warn(
		"Token's audience(s) is not in allowed list",
		zap.String("authDomain", c.authDomain),
		zap.Strings("allowedApplicationAudiences", c.allowedApplicationAudiences),
		zap.Strings("tokenAudiences", idToken.Audience),
	)
	return &Response{
		Allow: false,
		Response: http.Response{
			StatusCode: http.StatusUnauthorized,
		},
	}, nil
}
