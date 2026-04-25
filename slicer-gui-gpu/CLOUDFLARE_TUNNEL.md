# Cloudflare Tunnel Setup Guide for 3D Slicer

Cloudflare Tunnel provides secure, encrypted access to your 3D Slicer instance without exposing ports directly to the internet. It's ideal for remote access and integrations with the slicercloudapp.

## Prerequisites

1. **Cloudflare Account**: Free or paid plan (free tier works)
2. **Domain**: Domain must be pointed to Cloudflare nameservers
3. **Docker Compose**: Already installed
4. **Tunnel Credentials**: Generated from Cloudflare dashboard

## Step 1: Create Cloudflare Account & Add Domain

1. Go to [Cloudflare](https://dash.cloudflare.com)
2. Sign up or log in
3. Add your domain
4. Cloudflare will provide nameservers to update at your registrar
5. Wait for nameserver propagation (up to 48 hours)

## Step 2: Create a Tunnel

### Via Cloudflare Dashboard (Recommended for Beginners)

1. Go to **Cloudflare Dashboard** → **Access** (Zero Trust) → **Tunnels**
2. Click **Create tunnel**
3. Choose connector type: **Cloudflared**
4. Name your tunnel: `slicer-gui-gpu` (or your preferred name)
5. Click **Save tunnel**
6. Skip the "Install connector" section (we use Docker)
7. Copy your **Tunnel ID**
8. Go to **Public Hostnames** and skip for now

### Via Cloudflare API (Advanced)

```bash
# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create slicer-gui-gpu

# Get credentials
cat ~/.cloudflared/*.json
```

## Step 3: Get Your Tunnel Token

### Method 1: From Dashboard

1. In **Access** → **Tunnels**, select your tunnel
2. Click **Configure**
3. Copy the **Tunnel Token** from "Tunnel settings"

### Method 2: From CLI

```bash
# List tunnels
cloudflared tunnel list

# Show credentials
cat ~/.cloudflared/tunnel_id.json | jq .
```

## Step 4: Configure Environment Variables

Copy and edit `.env.local`:

```bash
cp .env.local.example .env.local
```

Edit `.env.local`:

```env
# Cloudflare Tunnel Configuration
CLOUDFLARE_TUNNEL_TOKEN=eyJhIjoiMTIzNDU2Nzg5MCIsImMiOiJvcmlnaW4tcHVsbCIsInMiOiJjZXJ0aWZpY2F0ZSIsInQiOiJ2MiJ9
CLOUDFLARE_TUNNEL_NAME=slicer-gui-gpu
CLOUDFLARE_TUNNEL_DOMAIN=slicer.example.com
```

**Where:**
- `CLOUDFLARE_TUNNEL_TOKEN`: Your tunnel token from Cloudflare dashboard
- `CLOUDFLARE_TUNNEL_NAME`: The name you gave the tunnel
- `CLOUDFLARE_TUNNEL_DOMAIN`: Your domain/subdomain (must be in Cloudflare DNS)

## Step 5: Configure DNS in Cloudflare

1. Go to **Cloudflare Dashboard** → **DNS**
2. Click **Add record**
3. Create CNAME record:
   - **Type**: CNAME
   - **Name**: `slicer` (or your subdomain)
   - **Target**: `tunnel-id.cfargotunnel.com`
   - **Proxy status**: Proxied (orange cloud)
4. Click **Save**

Or create A record:
   - **Type**: A
   - **Name**: `slicer.example.com`
   - **IPv4 Address**: `192.0.2.1` (any placeholder)
   - **Proxy status**: Proxied

## Step 6: Configure Tunnel Routing (Dashboard Method)

1. Go to **Access** → **Tunnels** → Select your tunnel
2. Click **Configure**
3. Go to **Public Hostnames**
4. Click **Add public hostname**
5. Fill in:
   - **Subdomain**: `slicer`
   - **Domain**: `example.com`
   - **Service**: HTTP
   - **URL**: `http://localhost:6080`
6. Click **Save**

## Step 7: Start Container with Cloudflare Tunnel

```bash
./docker-slicer.sh start

# Or directly
docker compose up -d
```

## Step 8: Verify Connection

1. Check logs:
   ```bash
   docker compose logs -f slicer
   ```

2. Look for success message:
   ```
   Starting Cloudflare Tunnel...
   INFO Registered tunnel connection connTunnelID=abc123...
   ```

3. Access your Slicer instance:
   ```
   https://slicer.example.com/vnc.html
   ```

## Testing & Troubleshooting

### Verify Tunnel Status

```bash
# Check if tunnel is running
docker compose exec slicer ps aux | grep cloudflared

# View tunnel logs
docker compose logs slicer | grep -i cloudflare
```

### Test Connection

```bash
# Local access still works
curl http://localhost:6080/

# From another machine
curl https://slicer.example.com/vnc.html
```

### Common Issues

#### "Error: 'cert.json' not found"
- **Solution**: Ensure `CLOUDFLARE_TUNNEL_TOKEN` is set correctly in `.env.local`
- Tokens should NOT be wrapped in quotes
- Check token format (should start with `eyJ`)

#### "Tunnel not authorized"
- **Solution**: Regenerate token from Cloudflare dashboard
- Clear old token: `rm .env.local && cp .env.local.example .env.local`
- Re-enter new token

#### "Connection refused on tunnel"
- **Solution**: Verify DNS is proxied (orange cloud) in Cloudflare dashboard
- Verify service URL is correct: `http://localhost:6080`
- Tunnel name and domain must match configuration

#### "404 Not Found"
- **Solution**: Check DNS record matches your configuration
- Verify subdomain matches tunnel config
- Ensure proxy is enabled for DNS record

## Advanced Configuration

### Custom Tunnel Configuration

Edit `.cloudflared/config.yml` inside container:

```bash
docker compose exec slicer bash
cat /home/slicer/.cloudflared/config.yml
```

### Multiple Services (Optional)

Route other services through same tunnel:

```bash
# Edit environment variable to create custom config
# Or modify the startup script
```

### SSL/TLS Settings

In Cloudflare dashboard:
1. Go to **SSL/TLS** → **Overview**
2. Set minimum TLS version: **1.2**
3. Enable **HSTS** for additional security:
   - Max Age: `31536000`
   - Include subdomains: ✓

### Access Control (Cloudflare Teams)

Add authentication to your tunnel:

1. Go to **Access** → **Applications**
2. Click **Add application**
3. Select **Self-hosted** application
4. Set domain: `slicer.example.com`
5. Add authentication policy (Email, Single Sign-On, etc.)
6. Assign to tunnel

## Security Best Practices

1. **Change VNC Password**:
   ```bash
   docker exec -it slicer-gui-gpu bash
   vncpasswd
   ```

2. **Enable Cloudflare Access** (Zero Trust):
   - Add authentication gateway
   - Require email verification
   - Implement SSO

3. **Rotate Tunnel Token**:
   ```bash
   # In Cloudflare dashboard: Tunnels → Select tunnel → Regenerate token
   ```

4. **Monitor Access**:
   - Check Cloudflare Analytics & Logs
   - Set up alerts for unusual activity

5. **Use Headers for Security**:
   In Cloudflare Dashboard → **Rules** → **Transform Rules**:
   ```
   Add header: X-Custom-Header = security-token
   ```

## Integration with slicercloudapp

### Backend Configuration

```python
# Example: Access Slicer remotely via tunnel
import requests

SLICER_URL = "https://slicer.example.com"

# Check tunnel status
response = requests.get(f"{SLICER_URL}/vnc.html")
print(f"Tunnel status: {response.status_code}")
```

### Web Application

```html
<!-- Embed Slicer in your web app -->
<iframe 
  src="https://slicer.example.com/vnc.html"
  width="100%"
  height="600px"
  allowfullscreen>
</iframe>
```

### API Integration

```bash
# Trigger processing via tunnel
curl -X POST https://slicer.example.com/api/process \
  -H "Content-Type: application/json" \
  -d '{"algorithm":"segmentation"}'
```

## Monitoring & Analytics

### In Cloudflare Dashboard

1. **Analytics & Logs**: View all requests to your tunnel
2. **Security**: Check blocked threats
3. **Performance**: Monitor latency and bandwidth

### Custom Logging

```bash
# View container logs with tunnel activity
docker compose logs -f slicer | grep -E "cloudflare|Tunnel"
```

## Cleanup

### Disable Tunnel (Keep Configuration)

```bash
# Just don't set CLOUDFLARE_TUNNEL_TOKEN
CLOUDFLARE_TUNNEL_TOKEN=
docker compose up -d
```

### Remove Tunnel (Delete Everything)

1. **In Cloudflare Dashboard**:
   - Go to **Access** → **Tunnels**
   - Select your tunnel
   - Click **Delete**

2. **Locally**:
   ```bash
   rm .cloudflared/
   ```

## Pricing

- **Free tier**: Unlimited Tunnels, basic features
- **Pro/Business**: Additional security, analytics, support
- **No bandwidth charges**: Unlike other solutions

## References

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Cloudflare Zero Trust](https://www.cloudflare.com/products/zero-trust/)
- [Cloudflare API Reference](https://developers.cloudflare.com/api/)

## Support

For issues:
1. Check Cloudflare dashboard for tunnel status
2. Review container logs: `docker compose logs slicer`
3. Verify DNS propagation: `nslookup slicer.example.com`
4. Test tunnel locally first: `curl http://localhost:6080`
