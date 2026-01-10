// Time Capsule Push Notification Checker
// Supabase Edge Function - runs via pg_cron
// 
// Checks for capsules where unlock_date has passed and sends push notifications

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts"

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// APNs Configuration
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')!
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')!
const APNS_PRIVATE_KEY = Deno.env.get('APNS_PRIVATE_KEY')!
const APNS_BUNDLE_ID = Deno.env.get('APNS_BUNDLE_ID')!

// Use production or sandbox based on environment
const APNS_HOST = Deno.env.get('APNS_PRODUCTION') === 'true'
    ? 'api.push.apple.com'
    : 'api.sandbox.push.apple.com'

// JWT Cache - APNs tokens are valid for up to 1 hour
let cachedJWT: string | null = null
let jwtExpiresAt: number = 0

serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        // Initialize Supabase client
        const supabaseUrl = Deno.env.get('SUPABASE_URL')!
        const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        const supabase = createClient(supabaseUrl, supabaseKey)

        console.log('🔍 Checking for unlockable capsules...')

        // Find capsules that should be unlocked
        const now = new Date().toISOString()
        const { data: capsules, error: capsuleError } = await supabase
            .from('time_capsules')
            .select(`
        id,
        title,
        recipient_id,
        created_by
      `)
            .lte('unlock_date', now)
            .eq('notification_sent', false)
            .eq('is_locked', true)

        if (capsuleError) {
            throw new Error(`Capsule query error: ${capsuleError.message}`)
        }

        if (!capsules || capsules.length === 0) {
            console.log('✅ No capsules to unlock')
            return new Response(
                JSON.stringify({ message: 'No capsules to unlock', count: 0 }),
                { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        console.log(`📦 Found ${capsules.length} capsules to process`)

        let successCount = 0
        let failCount = 0

        for (const capsule of capsules) {
            try {
                console.log(`📦 Processing capsule ${capsule.id} for recipient ${capsule.recipient_id}`)

                // Get recipient's APNs token
                const { data: profile, error: profileError } = await supabase
                    .from('profiles')
                    .select('apns_token, username')
                    .eq('id', capsule.recipient_id)
                    .single()

                if (profileError) {
                    console.log(`❌ Profile error for ${capsule.recipient_id}: ${profileError.message}`)
                    failCount++
                    continue
                }

                if (!profile?.apns_token) {
                    console.log(`⚠️ No APNs token for recipient ${capsule.recipient_id} (profile found but token is null/empty)`)
                    failCount++
                    continue
                }

                console.log(`✅ Found APNs token for ${capsule.recipient_id}: ${profile.apns_token.substring(0, 10)}...`)

                // Get sender's name
                const { data: sender } = await supabase
                    .from('profiles')
                    .select('username')
                    .eq('id', capsule.created_by)
                    .single()

                const senderName = sender?.username || 'Partneriniz'

                // Send APNs notification
                const sent = await sendAPNsNotification(
                    profile.apns_token,
                    `💌 ${senderName}'ten Gizli Mesaj!`,
                    capsule.title || 'Zaman kapsülün açıldı!',
                    { capsule_id: capsule.id }
                )

                if (sent) {
                    // Mark notification as sent - but DON'T unlock!
                    // The capsule will be unlocked when user opens it in the app
                    await supabase
                        .from('time_capsules')
                        .update({
                            notification_sent: true
                            // is_locked stays TRUE - user unlocks it by viewing
                        })
                        .eq('id', capsule.id)

                    console.log(`✅ Sent notification for capsule ${capsule.id}`)
                    successCount++
                } else {
                    failCount++
                }
            } catch (err) {
                console.error(`❌ Error processing capsule ${capsule.id}:`, err)
                failCount++
            }
        }

        return new Response(
            JSON.stringify({
                message: 'Capsules processed',
                success: successCount,
                failed: failCount
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error) {
        console.error('❌ Function error:', error)
        return new Response(
            JSON.stringify({ error: error.message }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})

// Generate JWT for APNs authentication (with caching)
async function generateAPNsJWT(): Promise<string> {
    // Check if we have a valid cached JWT (valid for 50 minutes to be safe, APNs accepts up to 1 hour)
    const now = Date.now()
    if (cachedJWT && jwtExpiresAt > now) {
        console.log('🔑 Using cached JWT')
        return cachedJWT
    }

    console.log('🔑 Generating new JWT...')

    // Fix key format - handle escaped newlines and ensure proper PKCS8 format
    let privateKeyPem = APNS_PRIVATE_KEY
        .replace(/\\n/g, '\n')  // Replace escaped \n with actual newlines
        .trim()

    // Ensure proper PEM format
    if (!privateKeyPem.includes('-----BEGIN PRIVATE KEY-----')) {
        privateKeyPem = `-----BEGIN PRIVATE KEY-----\n${privateKeyPem}\n-----END PRIVATE KEY-----`
    }

    const privateKey = await jose.importPKCS8(privateKeyPem, 'ES256')

    const jwt = await new jose.SignJWT({})
        .setProtectedHeader({
            alg: 'ES256',
            kid: APNS_KEY_ID
        })
        .setIssuer(APNS_TEAM_ID)
        .setIssuedAt()
        .sign(privateKey)

    // Cache the JWT for 50 minutes
    cachedJWT = jwt
    jwtExpiresAt = now + (50 * 60 * 1000)

    return jwt
}

// Send APNs push notification
async function sendAPNsNotification(
    deviceToken: string,
    title: string,
    body: string,
    data: Record<string, unknown>
): Promise<boolean> {
    try {
        console.log(`🔔 Sending APNs notification to token: ${deviceToken.substring(0, 10)}...`)
        console.log(`🔔 APNs Host: ${APNS_HOST}`)
        console.log(`🔔 Bundle ID: ${APNS_BUNDLE_ID}`)

        const jwt = await generateAPNsJWT()
        console.log(`🔑 JWT generated successfully`)

        const payload = {
            aps: {
                alert: {
                    title: title,
                    body: body
                },
                sound: 'default',
                badge: 1,
                'mutable-content': 1
            },
            ...data
        }

        console.log(`📤 Sending to: https://${APNS_HOST}/3/device/${deviceToken}`)

        const response = await fetch(
            `https://${APNS_HOST}/3/device/${deviceToken}`,
            {
                method: 'POST',
                headers: {
                    'authorization': `bearer ${jwt}`,
                    'apns-topic': APNS_BUNDLE_ID,
                    'apns-push-type': 'alert',
                    'apns-priority': '10',
                    'content-type': 'application/json'
                },
                body: JSON.stringify(payload)
            }
        )

        console.log(`📥 APNs response status: ${response.status}`)

        if (!response.ok) {
            const errorBody = await response.text()
            console.error(`❌ APNs error: ${response.status} - ${errorBody}`)
            return false
        }

        console.log(`✅ APNs notification sent successfully!`)
        return true
    } catch (error) {
        console.error('❌ APNs send error:', error)
        return false
    }
}
