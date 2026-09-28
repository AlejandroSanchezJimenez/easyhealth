const { initializeApp, cert } = require('firebase-admin/app')
const { getAuth } = require('firebase-admin/auth')
const serviceAccount = require('./service-account.json') // ← ajusta el nombre si es diferente

initializeApp({
  credential: cert(serviceAccount)
})

async function setRole(uid, role) {
  await getAuth().setCustomUserClaims(uid, { role })
  console.log(`✅ Rol "${role}" asignado al usuario ${uid}`)
}

// ── Cambia solo estas dos líneas ──
const UID = 'LW0VHiJW4mTIeP2NfPXsDkOA3293'
const ROLE = 'admin' // o 'teacher'

setRole(UID, ROLE)
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('❌ Error:', err)
    process.exit(1)
  })
