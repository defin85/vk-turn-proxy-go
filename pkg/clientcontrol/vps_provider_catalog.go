package clientcontrol

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/vpscatalog"
)

const (
	vpsProviderCatalogSyncEndpoint  = "/v1/vps-provider-catalogs:sync"
	vpsProviderCatalogIssueEndpoint = "/v1/vps-provider-catalogs/artifacts:issue"
)

var (
	ErrVPSProviderCatalogUnavailable = errors.New("vps provider catalog is unavailable")
	ErrVPSProviderCatalogInvalid     = errors.New("vps provider catalog is invalid")
	ErrVPSProviderArtifactNotReady   = errors.New("vps provider artifact is not ready")
)

type VPSProviderCatalogCapability struct {
	SyncEndpoint          string                             `json:"sync_endpoint"`
	ArtifactIssueEndpoint string                             `json:"artifact_issue_endpoint"`
	Endpoints             []VPSProviderCatalogEndpointStatus `json:"endpoints,omitempty"`
}

type VPSProviderCatalogEndpointConfig struct {
	ID            string `json:"id"`
	URL           string `json:"url"`
	Issuer        string `json:"issuer"`
	Audience      string `json:"audience"`
	ReadToken     string `json:"-"`
	IssueToken    string `json:"-"`
	AllowUnsigned bool   `json:"allow_unsigned,omitempty"`
}

type VPSProviderCatalogEndpointStatus struct {
	ID       string `json:"id"`
	URL      string `json:"url,omitempty"`
	Issuer   string `json:"issuer,omitempty"`
	Audience string `json:"audience,omitempty"`
}

type VPSProviderCatalogStatus struct {
	EndpointID       string     `json:"endpoint_id"`
	EndpointURL      string     `json:"endpoint_url,omitempty"`
	Issuer           string     `json:"issuer,omitempty"`
	Audience         string     `json:"audience,omitempty"`
	Generation       uint64     `json:"generation,omitempty"`
	GeneratedAt      *time.Time `json:"generated_at,omitempty"`
	ExpiresAt        *time.Time `json:"expires_at,omitempty"`
	LastSyncAt       *time.Time `json:"last_sync_at,omitempty"`
	ValidationStatus string     `json:"validation_status"`
	ValidationReason string     `json:"validation_reason,omitempty"`
	Message          string     `json:"message,omitempty"`
	SourceCount      int        `json:"source_count,omitempty"`
}

type RemoteProviderSourceDescriptor struct {
	EndpointID       string                        `json:"endpoint_id"`
	Issuer           string                        `json:"issuer,omitempty"`
	Audience         string                        `json:"audience,omitempty"`
	Generation       uint64                        `json:"generation,omitempty"`
	ProviderID       string                        `json:"provider_id"`
	SourceID         string                        `json:"source_id"`
	DisplayName      string                        `json:"display_name,omitempty"`
	Description      string                        `json:"description,omitempty"`
	SourceFamily     string                        `json:"source_family,omitempty"`
	HealthStatus     string                        `json:"health_status,omitempty"`
	EvidenceStatus   string                        `json:"evidence_status,omitempty"`
	ValidationStatus string                        `json:"validation_status"`
	ValidationReason string                        `json:"validation_reason,omitempty"`
	ArtifactOffers   []RemoteProviderArtifactOffer `json:"artifact_offers,omitempty"`
}

type RemoteProviderArtifactOffer struct {
	OfferID                string   `json:"offer_id"`
	Family                 string   `json:"family"`
	AccessMethods          []string `json:"access_methods,omitempty"`
	Actions                []string `json:"actions,omitempty"`
	RemoteEndpointFamily   string   `json:"remote_endpoint_family,omitempty"`
	RemoteEndpointRole     string   `json:"remote_endpoint_role,omitempty"`
	CompatibleProfileKinds []string `json:"compatible_profile_kinds,omitempty"`
	HealthStatus           string   `json:"health_status,omitempty"`
	EvidenceStatus         string   `json:"evidence_status,omitempty"`
	ValidationStatus       string   `json:"validation_status"`
	ValidationReason       string   `json:"validation_reason,omitempty"`
}

type VPSProviderArtifactIssueRequest struct {
	EndpointID   string `json:"endpoint_id"`
	SourceID     string `json:"source_id"`
	OfferID      string `json:"offer_id"`
	OperationID  string `json:"operation_id"`
	TTLSeconds   int    `json:"ttl_seconds,omitempty"`
	ExportSecret bool   `json:"export_secret,omitempty"`
}

type VPSProviderArtifactIssueResult struct {
	Resolution     Resolution               `json:"resolution"`
	RemoteArtifact RemoteVPSArtifactSummary `json:"remote_artifact"`
}

type cachedVPSProviderCatalog struct {
	endpoint VPSProviderCatalogEndpointConfig
	snapshot vpscatalog.CatalogSnapshot
	status   VPSProviderCatalogStatus
}

type vpsProviderCatalogCacheDisk struct {
	Version           int                                 `json:"version"`
	HighestGeneration map[string]uint64                   `json:"highest_generation,omitempty"`
	Catalogs          []vpsProviderCatalogCacheDiskRecord `json:"catalogs,omitempty"`
}

type vpsProviderCatalogCacheDiskRecord struct {
	EndpointID string                     `json:"endpoint_id"`
	Status     VPSProviderCatalogStatus   `json:"status"`
	Snapshot   vpscatalog.CatalogSnapshot `json:"snapshot,omitempty"`
}

func WithVPSProviderCatalogEndpoints(endpoints []VPSProviderCatalogEndpointConfig) Option {
	return func(cfg *hostConfig) {
		cfg.vpsCatalogEndpoints = cloneVPSEndpointConfigs(endpoints)
	}
}

func WithVPSProviderCatalogCachePath(path string) Option {
	return func(cfg *hostConfig) {
		cfg.vpsCatalogCachePath = strings.TrimSpace(path)
	}
}

func WithVPSProviderCatalogHTTPClient(client *http.Client) Option {
	return func(cfg *hostConfig) {
		cfg.vpsCatalogHTTPClient = client
	}
}

func defaultVPSProviderCatalogCapability(endpoints []VPSProviderCatalogEndpointConfig) VPSProviderCatalogCapability {
	statuses := make([]VPSProviderCatalogEndpointStatus, 0, len(endpoints))
	for _, endpoint := range endpoints {
		statuses = append(statuses, VPSProviderCatalogEndpointStatus{
			ID:       endpoint.ID,
			URL:      endpoint.URL,
			Issuer:   endpoint.Issuer,
			Audience: endpoint.Audience,
		})
	}
	return VPSProviderCatalogCapability{
		SyncEndpoint:          vpsProviderCatalogSyncEndpoint,
		ArtifactIssueEndpoint: vpsProviderCatalogIssueEndpoint,
		Endpoints:             statuses,
	}
}

func cloneVPSProviderCatalogCapability(
	capability *VPSProviderCatalogCapability,
) *VPSProviderCatalogCapability {
	if capability == nil {
		return nil
	}
	clone := *capability
	clone.Endpoints = append([]VPSProviderCatalogEndpointStatus(nil), capability.Endpoints...)
	return &clone
}

func (h *Host) SyncVPSProviderCatalogs(ctx context.Context) ([]VPSProviderCatalogStatus, error) {
	h.mu.Lock()
	endpoints := cloneVPSEndpointConfigs(h.vpsCatalogEndpoints)
	client := h.vpsCatalogHTTPClient
	if client == nil {
		client = http.DefaultClient
	}
	h.mu.Unlock()
	if len(endpoints) == 0 {
		return nil, ErrVPSProviderCatalogUnavailable
	}
	statuses := make([]VPSProviderCatalogStatus, 0, len(endpoints))
	var firstErr error
	for _, endpoint := range endpoints {
		status, err := h.syncVPSProviderCatalog(ctx, client, endpoint)
		statuses = append(statuses, status)
		if err != nil && firstErr == nil {
			firstErr = err
		}
	}
	return statuses, firstErr
}

func (h *Host) VPSProviderCatalogs() []VPSProviderCatalogStatus {
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.remoteCatalogStatusesLocked()
}

func (h *Host) remoteCatalogStatusesLocked() []VPSProviderCatalogStatus {
	statuses := make([]VPSProviderCatalogStatus, 0, len(h.vpsCatalogEndpoints))
	for _, endpoint := range h.vpsCatalogEndpoints {
		if cache, ok := h.vpsCatalogCache[endpoint.ID]; ok {
			statuses = append(statuses, h.currentVPSCatalogStatusLocked(cache))
			continue
		}
		statuses = append(statuses, VPSProviderCatalogStatus{
			EndpointID:       endpoint.ID,
			EndpointURL:      endpoint.URL,
			Issuer:           endpoint.Issuer,
			Audience:         endpoint.Audience,
			ValidationStatus: string(vpscatalog.ValidationStatusUnavailable),
			Message:          "catalog has not been synced",
		})
	}
	return statuses
}

func (h *Host) RemoteProviderSources() []RemoteProviderSourceDescriptor {
	h.mu.Lock()
	defer h.mu.Unlock()
	out := make([]RemoteProviderSourceDescriptor, 0)
	for _, endpoint := range h.vpsCatalogEndpoints {
		cache, ok := h.vpsCatalogCache[endpoint.ID]
		if !ok {
			continue
		}
		status := h.currentVPSCatalogStatusLocked(cache)
		for _, source := range cache.snapshot.Sources {
			sourceStatus := status.ValidationStatus
			sourceReason := status.ValidationReason
			if sourceStatus == string(vpscatalog.ValidationStatusValid) {
				readiness := vpscatalog.ValidateOfferReadiness(source, firstOffer(source), h.now().UTC())
				sourceStatus = string(readiness.Status)
				sourceReason = readiness.Reason
			}
			descriptor := RemoteProviderSourceDescriptor{
				EndpointID:       cache.snapshot.EndpointID,
				Issuer:           cache.snapshot.Issuer,
				Audience:         cache.snapshot.Audience,
				Generation:       cache.snapshot.Generation,
				ProviderID:       source.ProviderID,
				SourceID:         source.ID,
				DisplayName:      source.DisplayName,
				Description:      source.Description,
				SourceFamily:     source.SourceFamily,
				HealthStatus:     string(source.Health.Status),
				EvidenceStatus:   string(firstEvidenceStatus(source.Evidence)),
				ValidationStatus: sourceStatus,
				ValidationReason: sourceReason,
			}
			for _, offer := range source.ArtifactOffers {
				readiness := vpscatalog.ValidationResult{Status: vpscatalog.ValidationStatus(status.ValidationStatus), Reason: status.ValidationReason}
				if status.ValidationStatus == string(vpscatalog.ValidationStatusValid) {
					readiness = vpscatalog.ValidateOfferReadiness(source, offer, h.now().UTC())
				}
				descriptor.ArtifactOffers = append(descriptor.ArtifactOffers, RemoteProviderArtifactOffer{
					OfferID:                offer.ID,
					Family:                 offer.Family,
					AccessMethods:          append([]string(nil), offer.AccessMethods...),
					Actions:                append([]string(nil), offer.Actions...),
					RemoteEndpointFamily:   offer.RemoteEndpointFamily,
					RemoteEndpointRole:     offer.RemoteEndpointRole,
					CompatibleProfileKinds: append([]string(nil), offer.CompatibleProfileKinds...),
					HealthStatus:           string(offer.Health.Status),
					EvidenceStatus:         string(firstEvidenceStatus(offer.Evidence)),
					ValidationStatus:       string(readiness.Status),
					ValidationReason:       readiness.Reason,
				})
			}
			out = append(out, descriptor)
		}
	}
	return out
}

func (h *Host) IssueVPSProviderArtifact(
	ctx context.Context,
	req VPSProviderArtifactIssueRequest,
) (VPSProviderArtifactIssueResult, error) {
	req.EndpointID = strings.TrimSpace(req.EndpointID)
	req.SourceID = strings.TrimSpace(req.SourceID)
	req.OfferID = strings.TrimSpace(req.OfferID)
	req.OperationID = strings.TrimSpace(req.OperationID)
	if req.OperationID == "" {
		return VPSProviderArtifactIssueResult{}, fmt.Errorf("%w: operation_id is required", ErrVPSProviderCatalogInvalid)
	}

	h.mu.Lock()
	cache, ok := h.vpsCatalogCache[req.EndpointID]
	client := h.vpsCatalogHTTPClient
	if client == nil {
		client = http.DefaultClient
	}
	if !ok {
		h.mu.Unlock()
		return VPSProviderArtifactIssueResult{}, ErrVPSProviderCatalogUnavailable
	}
	status := h.currentVPSCatalogStatusLocked(cache)
	if status.ValidationStatus != string(vpscatalog.ValidationStatusValid) {
		h.mu.Unlock()
		return VPSProviderArtifactIssueResult{}, fmt.Errorf("%w: %s", ErrVPSProviderCatalogInvalid, status.Message)
	}
	source, offer, found := findVPSCatalogOffer(cache.snapshot, req.SourceID, req.OfferID)
	if !found {
		h.mu.Unlock()
		return VPSProviderArtifactIssueResult{}, fmt.Errorf("%w: source or offer was not found", ErrVPSProviderCatalogInvalid)
	}
	readiness := vpscatalog.ValidateOfferReadiness(source, offer, h.now().UTC())
	if readiness.Status != vpscatalog.ValidationStatusValid {
		h.mu.Unlock()
		return VPSProviderArtifactIssueResult{}, fmt.Errorf("%w: %s", ErrVPSProviderArtifactNotReady, readiness.Message)
	}
	endpoint := cache.endpoint
	h.mu.Unlock()

	response, err := issueRemoteVPSArtifact(ctx, client, endpoint, req)
	if err != nil {
		return VPSProviderArtifactIssueResult{}, err
	}
	if response.Source.SourceID != req.SourceID ||
		response.Artifact.OfferID != req.OfferID ||
		response.Source.EndpointID != cache.snapshot.EndpointID {
		return VPSProviderArtifactIssueResult{}, fmt.Errorf("%w: remote artifact response does not match cached source", ErrVPSProviderCatalogInvalid)
	}
	if response.Source.Generation < cache.snapshot.Generation {
		return VPSProviderArtifactIssueResult{}, fmt.Errorf("%w: remote artifact response rolled back below cached generation", ErrVPSProviderCatalogInvalid)
	}
	resolution, err := h.recordVPSIssuedResolution(req, response, source, offer, readiness)
	if err != nil {
		return VPSProviderArtifactIssueResult{}, err
	}
	return VPSProviderArtifactIssueResult{
		Resolution:     resolution,
		RemoteArtifact: *resolution.RemoteVPS,
	}, nil
}

func (h *Host) syncVPSProviderCatalog(
	ctx context.Context,
	client *http.Client,
	endpoint VPSProviderCatalogEndpointConfig,
) (VPSProviderCatalogStatus, error) {
	now := h.now().UTC()
	status := VPSProviderCatalogStatus{
		EndpointID:       endpoint.ID,
		EndpointURL:      endpoint.URL,
		Issuer:           endpoint.Issuer,
		Audience:         endpoint.Audience,
		LastSyncAt:       &now,
		ValidationStatus: string(vpscatalog.ValidationStatusInvalid),
	}
	if err := validateVPSEndpointConfig(endpoint); err != nil {
		status.Message = err.Error()
		_ = h.storeVPSCatalogStatus(endpoint, status, nil)
		return status, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, joinVPSCatalogURL(endpoint.URL, vpscatalog.DefaultCatalogPath), nil)
	if err != nil {
		status.Message = err.Error()
		_ = h.storeVPSCatalogStatus(endpoint, status, nil)
		return status, err
	}
	if endpoint.ReadToken != "" {
		req.Header.Set("Authorization", "Bearer "+endpoint.ReadToken)
	}
	resp, err := client.Do(req)
	if err != nil {
		status.ValidationStatus = string(vpscatalog.ValidationStatusUnavailable)
		status.Message = err.Error()
		_ = h.storeVPSCatalogStatus(endpoint, status, nil)
		return status, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		err := fmt.Errorf("catalog endpoint returned status %d", resp.StatusCode)
		status.ValidationStatus = string(vpscatalog.ValidationStatusUnavailable)
		status.Message = err.Error()
		_ = h.storeVPSCatalogStatus(endpoint, status, nil)
		return status, err
	}
	var snapshot vpscatalog.CatalogSnapshot
	if err := json.NewDecoder(resp.Body).Decode(&snapshot); err != nil {
		status.Message = err.Error()
		_ = h.storeVPSCatalogStatus(endpoint, status, nil)
		return status, err
	}
	h.mu.Lock()
	highest := h.vpsCatalogHighestGeneration[vpsCatalogGenerationKey(endpoint)]
	h.mu.Unlock()
	result, validationErr := vpscatalog.ValidateSnapshot(snapshot, vpscatalog.ValidationOptions{
		Now:                       now,
		ExpectedIssuer:            endpoint.Issuer,
		ExpectedAudience:          endpoint.Audience,
		ExpectedEndpointID:        endpoint.ID,
		HighestAcceptedGeneration: highest,
		RequireSigned:             !endpoint.AllowUnsigned,
	})
	status = vpsCatalogStatusFromSnapshot(endpoint, snapshot, now, result)
	if validationErr != nil {
		_ = h.storeVPSCatalogStatus(endpoint, status, nil)
		return status, validationErr
	}
	if err := h.storeVPSCatalogStatus(endpoint, status, &snapshot); err != nil {
		return status, err
	}
	return status, nil
}

func (h *Host) storeVPSCatalogStatus(
	endpoint VPSProviderCatalogEndpointConfig,
	status VPSProviderCatalogStatus,
	snapshot *vpscatalog.CatalogSnapshot,
) error {
	h.mu.Lock()
	defer h.mu.Unlock()
	cache := h.vpsCatalogCache[endpoint.ID]
	cache.endpoint = endpoint
	cache.status = status
	if snapshot != nil {
		cache.snapshot = vpscatalog.CloneSnapshot(*snapshot)
		key := vpsCatalogGenerationKey(endpoint)
		if snapshot.Generation > h.vpsCatalogHighestGeneration[key] {
			h.vpsCatalogHighestGeneration[key] = snapshot.Generation
		}
	} else if status.ValidationStatus != string(vpscatalog.ValidationStatusUnavailable) {
		cache.snapshot = vpscatalog.CatalogSnapshot{}
	}
	h.vpsCatalogCache[endpoint.ID] = cache
	return h.persistVPSProviderCatalogCacheLocked()
}

func (h *Host) loadVPSProviderCatalogCache() error {
	if strings.TrimSpace(h.vpsCatalogCachePath) == "" {
		return nil
	}
	data, err := os.ReadFile(h.vpsCatalogCachePath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil
		}
		return err
	}
	var disk vpsProviderCatalogCacheDisk
	if err := json.Unmarshal(data, &disk); err != nil {
		return err
	}
	if disk.Version != 1 {
		return fmt.Errorf("%w: unsupported vps provider catalog cache version %d", ErrVPSProviderCatalogInvalid, disk.Version)
	}

	endpoints := make(map[string]VPSProviderCatalogEndpointConfig, len(h.vpsCatalogEndpoints))
	for _, endpoint := range h.vpsCatalogEndpoints {
		endpoints[endpoint.ID] = endpoint
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	h.vpsCatalogCache = make(map[string]cachedVPSProviderCatalog)
	h.vpsCatalogHighestGeneration = make(map[string]uint64)
	for _, endpoint := range h.vpsCatalogEndpoints {
		key := vpsCatalogGenerationKey(endpoint)
		if generation := disk.HighestGeneration[key]; generation > 0 {
			h.vpsCatalogHighestGeneration[key] = generation
		}
	}
	for _, record := range disk.Catalogs {
		endpoint, ok := endpoints[strings.TrimSpace(record.EndpointID)]
		if !ok {
			continue
		}
		cache := cachedVPSProviderCatalog{
			endpoint: endpoint,
			status:   record.Status,
		}
		if record.Snapshot.Version != "" {
			cache.snapshot = vpscatalog.CloneSnapshot(record.Snapshot)
			key := vpsCatalogGenerationKey(endpoint)
			if record.Snapshot.Generation > h.vpsCatalogHighestGeneration[key] {
				h.vpsCatalogHighestGeneration[key] = record.Snapshot.Generation
			}
		}
		h.vpsCatalogCache[endpoint.ID] = cache
	}
	return nil
}

func (h *Host) persistVPSProviderCatalogCacheLocked() error {
	if strings.TrimSpace(h.vpsCatalogCachePath) == "" {
		return nil
	}

	highest := make(map[string]uint64, len(h.vpsCatalogHighestGeneration))
	highestKeys := make([]string, 0, len(h.vpsCatalogHighestGeneration))
	for key := range h.vpsCatalogHighestGeneration {
		highestKeys = append(highestKeys, key)
	}
	sort.Strings(highestKeys)
	for _, key := range highestKeys {
		if h.vpsCatalogHighestGeneration[key] > 0 {
			highest[key] = h.vpsCatalogHighestGeneration[key]
		}
	}

	records := make([]vpsProviderCatalogCacheDiskRecord, 0, len(h.vpsCatalogCache))
	endpoints := cloneVPSEndpointConfigs(h.vpsCatalogEndpoints)
	sort.Slice(endpoints, func(i, j int) bool { return endpoints[i].ID < endpoints[j].ID })
	for _, endpoint := range endpoints {
		cache, ok := h.vpsCatalogCache[endpoint.ID]
		if !ok {
			continue
		}
		record := vpsProviderCatalogCacheDiskRecord{
			EndpointID: endpoint.ID,
			Status:     cache.status,
		}
		if cache.snapshot.Version != "" {
			record.Snapshot = vpscatalog.CloneSnapshot(cache.snapshot)
		}
		records = append(records, record)
	}
	disk := vpsProviderCatalogCacheDisk{
		Version:           1,
		HighestGeneration: highest,
		Catalogs:          records,
	}
	data, err := json.MarshalIndent(disk, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')

	path := strings.TrimSpace(h.vpsCatalogCachePath)
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, ".vps-provider-catalog-*.tmp")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	closed := false
	defer func() {
		if !closed {
			_ = tmp.Close()
		}
		_ = os.Remove(tmpPath)
	}()
	if err := tmp.Chmod(0o600); err != nil {
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		return err
	}
	if err := tmp.Sync(); err != nil {
		return err
	}
	if err := tmp.Close(); err != nil {
		closed = true
		return err
	}
	closed = true
	if err := os.Rename(tmpPath, path); err != nil {
		return err
	}
	return os.Chmod(path, 0o600)
}

func (h *Host) currentVPSCatalogStatusLocked(cache cachedVPSProviderCatalog) VPSProviderCatalogStatus {
	if cache.snapshot.Version == "" {
		return cache.status
	}
	highest := h.vpsCatalogHighestGeneration[vpsCatalogGenerationKey(cache.endpoint)]
	result, _ := vpscatalog.ValidateSnapshot(cache.snapshot, vpscatalog.ValidationOptions{
		Now:                       h.now().UTC(),
		ExpectedIssuer:            cache.endpoint.Issuer,
		ExpectedAudience:          cache.endpoint.Audience,
		ExpectedEndpointID:        cache.endpoint.ID,
		HighestAcceptedGeneration: highest,
		RequireSigned:             !cache.endpoint.AllowUnsigned,
	})
	status := vpsCatalogStatusFromSnapshot(cache.endpoint, cache.snapshot, timeOrNow(cache.status.LastSyncAt, h.now), result)
	if status.LastSyncAt == nil {
		status.LastSyncAt = cache.status.LastSyncAt
	}
	return status
}

func issueRemoteVPSArtifact(
	ctx context.Context,
	client *http.Client,
	endpoint VPSProviderCatalogEndpointConfig,
	req VPSProviderArtifactIssueRequest,
) (vpscatalog.ArtifactIssueResponse, error) {
	body, err := json.Marshal(vpscatalog.ArtifactIssueRequest{
		SourceID:     req.SourceID,
		OfferID:      req.OfferID,
		OperationID:  req.OperationID,
		TTLSeconds:   req.TTLSeconds,
		ExportSecret: req.ExportSecret,
	})
	if err != nil {
		return vpscatalog.ArtifactIssueResponse{}, err
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, joinVPSCatalogURL(endpoint.URL, vpscatalog.DefaultArtifactIssuePath), bytes.NewReader(body))
	if err != nil {
		return vpscatalog.ArtifactIssueResponse{}, err
	}
	httpReq.Header.Set("Content-Type", "application/json")
	if endpoint.IssueToken != "" {
		httpReq.Header.Set("Authorization", "Bearer "+endpoint.IssueToken)
	}
	resp, err := client.Do(httpReq)
	if err != nil {
		return vpscatalog.ArtifactIssueResponse{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return vpscatalog.ArtifactIssueResponse{}, fmt.Errorf("artifact issue endpoint returned status %d", resp.StatusCode)
	}
	var response vpscatalog.ArtifactIssueResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return vpscatalog.ArtifactIssueResponse{}, err
	}
	return response, nil
}

func (h *Host) recordVPSIssuedResolution(
	req VPSProviderArtifactIssueRequest,
	response vpscatalog.ArtifactIssueResponse,
	source vpscatalog.ProviderSource,
	offer vpscatalog.ArtifactOffer,
	readiness vpscatalog.ValidationResult,
) (Resolution, error) {
	resolutionID, err := h.allocateResolutionID()
	if err != nil {
		return Resolution{}, err
	}
	now := h.now().UTC()
	expiresAt := response.ExpiresAt.UTC()
	remoteSummary := remoteVPSArtifactSummary(response, readiness)
	remoteExportPayload := remoteVPSExportPayload(response)
	exportSupported := remoteExportPayload != ""
	artifact := &ResolutionArtifact{
		Family:        ArtifactFamily(response.Artifact.Family),
		AccessMethods: runtimeAccessMethodsFromStrings(response.Artifact.AccessMethods),
		Actions:       vpsResolutionActions(response.Artifact.Actions, ArtifactFamily(response.Artifact.Family), h.platformTunnels),
		Summary: ResolutionArtifactSummary{
			RemoteVPS: &remoteSummary,
		},
	}
	state := ResolutionStateResolved
	var expiredAt *time.Time
	if !expiresAt.After(now) {
		state = ResolutionStateExpired
		expiredAt = &now
		exportSupported = false
		artifact.Actions = nil
	}
	snapshot := Resolution{
		ID:               resolutionID,
		Provider:         source.ProviderID,
		ResolutionMethod: "vps_catalog_issue",
		Input: ResolutionInput{
			Provider:     source.ProviderID,
			Kind:         ProviderInputKindRemoteVPSCatalog,
			LinkRedacted: fmt.Sprintf("vps-catalog://%s/%s/%s", response.Source.EndpointID, req.SourceID, req.OfferID),
		},
		Artifact:   artifact,
		State:      state,
		Export:     ResolutionExportStatus{Supported: exportSupported, ExpiresAt: &expiresAt, ExpirySource: "vps_catalog_artifact_ttl"},
		StartedAt:  now,
		UpdatedAt:  now,
		ResolvedAt: &now,
		ExpiredAt:  expiredAt,
		RemoteVPS:  &remoteSummary,
	}
	eventType := EventResolutionResolved
	message := ""
	if state == ResolutionStateExpired {
		eventType = EventResolutionExpired
		message = "expired"
	}
	event := resolutionSnapshotEvent(snapshot, eventType, message)
	done := make(chan struct{})
	close(done)
	managed := &managedResolution{
		snapshot: snapshot,
		descriptor: ProviderDescriptor{
			ID:               source.ProviderID,
			DisplayName:      source.DisplayName,
			InputKind:        ProviderInputKindRemoteVPSCatalog,
			ArtifactFamilies: []ArtifactFamily{ArtifactFamily(offer.Family)},
			CapabilityHints: ProviderCapabilityHints{
				PotentialActions: artifactActionsFromStrings(offer.Actions),
			},
		},
		done:                done,
		remoteExportPayload: remoteExportPayload,
		events:              []Event{event},
		input: StartResolutionRequest{
			Provider: source.ProviderID,
			Input: &ProviderInputEnvelope{
				Kind: ProviderInputKindRemoteVPSCatalog,
			},
		},
	}
	h.mu.Lock()
	h.resolutions[resolutionID] = managed
	h.mu.Unlock()
	h.publishEvent(event)
	return snapshot, nil
}

func vpsCatalogStatusFromSnapshot(
	endpoint VPSProviderCatalogEndpointConfig,
	snapshot vpscatalog.CatalogSnapshot,
	lastSyncAt time.Time,
	result vpscatalog.ValidationResult,
) VPSProviderCatalogStatus {
	generatedAt := snapshot.GeneratedAt.UTC()
	expiresAt := snapshot.ExpiresAt.UTC()
	last := lastSyncAt.UTC()
	return VPSProviderCatalogStatus{
		EndpointID:       endpoint.ID,
		EndpointURL:      endpoint.URL,
		Issuer:           snapshot.Issuer,
		Audience:         snapshot.Audience,
		Generation:       snapshot.Generation,
		GeneratedAt:      &generatedAt,
		ExpiresAt:        &expiresAt,
		LastSyncAt:       &last,
		ValidationStatus: string(result.Status),
		ValidationReason: result.Reason,
		Message:          result.Message,
		SourceCount:      len(snapshot.Sources),
	}
}

func remoteVPSArtifactSummary(
	response vpscatalog.ArtifactIssueResponse,
	readiness vpscatalog.ValidationResult,
) RemoteVPSArtifactSummary {
	expiresAt := response.ExpiresAt.UTC()
	return RemoteVPSArtifactSummary{
		EndpointID:       response.Source.EndpointID,
		Issuer:           response.Source.Issuer,
		Audience:         response.Source.Audience,
		Generation:       response.Source.Generation,
		SourceID:         response.Source.SourceID,
		OfferID:          response.Artifact.OfferID,
		ArtifactID:       response.Artifact.ID,
		HealthStatus:     string(response.Artifact.Health.Status),
		EvidenceStatus:   string(firstEvidenceStatus(response.Artifact.Evidence)),
		ValidationStatus: string(readiness.Status),
		ValidationReason: readiness.Reason,
		ExpiresAt:        &expiresAt,
		Redaction: RedactionSummary{
			OrdinaryReads:  string(response.Redaction.OrdinaryReads),
			Events:         string(response.Redaction.Events),
			Diagnostics:    string(response.Redaction.Diagnostics),
			PersistedState: string(response.Redaction.PersistedState),
			Export:         string(response.Redaction.Export),
		},
	}
}

func remoteVPSExportPayload(response vpscatalog.ArtifactIssueResponse) string {
	if response.Export == nil || response.Export.PayloadRedacted {
		return ""
	}
	return strings.TrimSpace(response.Export.Payload)
}

func validateVPSEndpointConfig(endpoint VPSProviderCatalogEndpointConfig) error {
	if strings.TrimSpace(endpoint.ID) == "" {
		return errors.New("vps catalog endpoint id is required")
	}
	if strings.TrimSpace(endpoint.URL) == "" {
		return errors.New("vps catalog endpoint url is required")
	}
	parsed, err := url.Parse(strings.TrimSpace(endpoint.URL))
	if err != nil || parsed.Scheme == "" || parsed.Host == "" {
		return fmt.Errorf("vps catalog endpoint url %q is invalid", endpoint.URL)
	}
	if strings.TrimSpace(endpoint.Issuer) == "" {
		return errors.New("vps catalog endpoint issuer is required")
	}
	if strings.TrimSpace(endpoint.Audience) == "" {
		return errors.New("vps catalog endpoint audience is required")
	}
	return nil
}

func joinVPSCatalogURL(base string, path string) string {
	return strings.TrimRight(strings.TrimSpace(base), "/") + path
}

func findVPSCatalogOffer(snapshot vpscatalog.CatalogSnapshot, sourceID string, offerID string) (vpscatalog.ProviderSource, vpscatalog.ArtifactOffer, bool) {
	for _, source := range snapshot.Sources {
		if source.ID != sourceID {
			continue
		}
		for _, offer := range source.ArtifactOffers {
			if offer.ID == offerID {
				return vpscatalog.CloneSource(source), vpscatalog.CloneOffer(offer), true
			}
		}
	}
	return vpscatalog.ProviderSource{}, vpscatalog.ArtifactOffer{}, false
}

func firstOffer(source vpscatalog.ProviderSource) vpscatalog.ArtifactOffer {
	if len(source.ArtifactOffers) == 0 {
		return vpscatalog.ArtifactOffer{}
	}
	return source.ArtifactOffers[0]
}

func firstEvidenceStatus(evidence []vpscatalog.Evidence) vpscatalog.EvidenceStatus {
	if len(evidence) == 0 {
		return vpscatalog.EvidenceStatusMissing
	}
	return evidence[0].Status
}

func runtimeAccessMethodsFromStrings(values []string) []RuntimeAccessMethod {
	out := make([]RuntimeAccessMethod, 0, len(values))
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			out = append(out, RuntimeAccessMethod(strings.TrimSpace(value)))
		}
	}
	return out
}

func artifactActionsFromStrings(values []string) []ArtifactAction {
	out := make([]ArtifactAction, 0, len(values))
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			out = append(out, ArtifactAction(strings.TrimSpace(value)))
		}
	}
	return out
}

func vpsResolutionActions(values []string, family ArtifactFamily, platformTunnels []PlatformTunnelCapability) []ResolutionAction {
	actions := artifactActionsFromStrings(values)
	if len(actions) == 0 {
		actions = []ArtifactAction{ArtifactActionStartOnThisDevice}
	}
	out := make([]ResolutionAction, 0, len(actions))
	for _, action := range actions {
		out = append(out, ResolutionAction{
			ID:             action,
			ExecutionOwner: artifactActionExecutionOwner(action),
			ExecutionPlans: resolutionExecutionPlansForAction(action, family, platformTunnels),
		})
	}
	return out
}

func cloneVPSEndpointConfigs(endpoints []VPSProviderCatalogEndpointConfig) []VPSProviderCatalogEndpointConfig {
	if len(endpoints) == 0 {
		return nil
	}
	out := make([]VPSProviderCatalogEndpointConfig, 0, len(endpoints))
	for _, endpoint := range endpoints {
		endpoint.ID = strings.TrimSpace(endpoint.ID)
		endpoint.URL = strings.TrimRight(strings.TrimSpace(endpoint.URL), "/")
		endpoint.Issuer = strings.TrimSpace(endpoint.Issuer)
		endpoint.Audience = strings.TrimSpace(endpoint.Audience)
		endpoint.ReadToken = strings.TrimSpace(endpoint.ReadToken)
		endpoint.IssueToken = strings.TrimSpace(endpoint.IssueToken)
		out = append(out, endpoint)
	}
	return out
}

func vpsCatalogGenerationKey(endpoint VPSProviderCatalogEndpointConfig) string {
	return strings.Join([]string{endpoint.ID, endpoint.Issuer, endpoint.Audience}, "|")
}

func timeOrNow(value *time.Time, now func() time.Time) time.Time {
	if value != nil {
		return value.UTC()
	}
	if now != nil {
		return now().UTC()
	}
	return time.Now().UTC()
}
