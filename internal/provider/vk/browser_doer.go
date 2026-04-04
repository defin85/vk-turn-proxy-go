package vk

import (
	"errors"
	"net/http"
	"net/http/cookiejar"
	"net/url"
)

type cookieDoer struct {
	base    httpDoer
	jar     http.CookieJar
	targets []*url.URL
}

func newCookieDoer(base httpDoer, targetURLs []string, cookies []*http.Cookie) (httpDoer, error) {
	jar, err := cookiejar.New(nil)
	if err != nil {
		return nil, err
	}

	parsed := make([]*url.URL, 0, len(targetURLs))
	for _, rawURL := range targetURLs {
		if rawURL == "" {
			continue
		}
		parsedURL, err := url.Parse(rawURL)
		if err != nil {
			continue
		}
		if parsedURL.Scheme == "" || parsedURL.Host == "" {
			continue
		}
		parsed = append(parsed, parsedURL)
	}
	if len(parsed) == 0 {
		return nil, errors.New("no valid browser continuation URLs")
	}
	for _, parsedURL := range parsed {
		jar.SetCookies(parsedURL, cookies)
	}

	return &cookieDoer{
		base:    base,
		jar:     jar,
		targets: parsed,
	}, nil
}

func (d *cookieDoer) Do(request *http.Request) (*http.Response, error) {
	clone := request.Clone(request.Context())
	for _, cookie := range d.jar.Cookies(clone.URL) {
		clone.AddCookie(cookie)
	}

	return d.base.Do(clone)
}
