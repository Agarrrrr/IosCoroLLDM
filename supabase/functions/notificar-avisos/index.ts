import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import webpush from "https://esm.sh/web-push@3.6.7"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    // 1. Recibir el "Webhook" (El nuevo Aviso)
    const payload = await req.json()
    console.log("DEBUG Payload:", JSON.stringify(payload, null, 2))
    const aviso = payload.record // Los datos del nuevo registro en la tabla avisos

    if (!aviso || !aviso.mensaje) throw new Error("Aviso inválido")

    // Abortar silenciosamente si es una sincronización en segundo plano (Eliminaciones)
    if (aviso.metadata?.subtipo === 'SYNC_SILENCIOSA') {
      return new Response(JSON.stringify({ msg: "Sync silenciosa ignorada para Push" }), { headers: corsHeaders })
    }

    // 2. Conectar a tu base de datos (con permisos de Admin para leer los perfiles)
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 3. Buscar a todas las suscripciones de los usuarios que pertenezcan a ese coro (o a todos si es estatal)
    let query = supabase.from('suscripciones_push').select('suscripcion, perfiles!inner(coro_id)')
    
    if (aviso.coro_id !== 'estatal') {
      query = query.eq('perfiles.coro_id', aviso.coro_id)
    }
    
    const { data: suscripciones, error } = await query
    if (error) throw error
    if (!suscripciones || suscripciones.length === 0) return new Response(JSON.stringify({ msg: "Nadie suscrito" }), { headers: corsHeaders })

    // 4. Configurar tus llaves maestras VAPID
    webpush.setVapidDetails(
      'mailto:contacto@lldmcorobc.com', // Puedes cambiarlo luego
      Deno.env.get('VAPID_PUBLIC_KEY') ?? '',
      Deno.env.get('VAPID_PRIVATE_KEY') ?? ''
    )

    // 5. Preparar la notificación con contexto inteligente
    let titulo = 'Recordatorio de Sede'
    let cuerpo = aviso.mensaje
    let url = '/'

    if (aviso.tipo === 'VIVO') {
      titulo = aviso.coro_id === 'estatal' ? 'ESTATAL CANTANDO' : 'CANTANDO AHORA'
      cuerpo = `EN VIVO: ${aviso.mensaje.toUpperCase()}`
      url = `/?canto=${aviso.metadata?.id_canto}`
    } else if (aviso.metadata?.subtipo === 'NUEVO_CANTO') {
      titulo = 'NUEVO CANTO AÑADIDO'
      cuerpo = `SE HA AÑADIDO: ${aviso.mensaje.toUpperCase()}`
      url = `/?canto=${aviso.metadata?.id_canto}`
    }

    const notificacion = JSON.stringify({
      title: titulo,
      body: cuerpo,
      tipo: aviso.tipo,
      subtipo: aviso.metadata?.subtipo || null,
      canto_id: aviso.metadata?.id_canto || null,
      url: url
    })

    // 6. Enviar a Google/Apple masivamente
    const promesas = suscripciones.map(async (registro) => {
      try {
        const sub = typeof registro.suscripcion === 'string' ? JSON.parse(registro.suscripcion) : registro.suscripcion
        await webpush.sendNotification(sub, notificacion)
      } catch (err) {
        // Si el usuario revocó el permiso desde el navegador, la llave expira.
        console.log(`Fallo enviando a dispositivo:`, err.message)
      }
    })

    await Promise.all(promesas)

    return new Response(JSON.stringify({ exito: true, enviados: suscripciones.length }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})