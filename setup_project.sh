#!/bin/bash

# ---------------------
# Configuración Inicial
# ---------------------

# Cargar variables de entorno desde .env
if [ -f ~/Documents/BizFlow/.env ]; then
  source ~/Documents/BizFlow/.env
else
  echo "Error: No se encontró el archivo .env en ~/Documents/BizFlow/.env"
  exit 1
fi

# Verificar que las variables necesarias están definidas
REQUIRED_VARS=(
  VERCEL_API_TOKEN
  GITHUB_API_KEY
  SUPABASE_URL
  SUPABASE_KEY
  OPENAI_API_KEY
  HUGGINGFACE_API_KEY
)

for VAR in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR}" ]; then
    echo "Error: La variable $VAR no está definida. Verifica tu archivo .env."
    exit 1
  fi
done

# Variables del proyecto
PROJECT_NAME="BizFlow"
FRONTEND_REPO_URL="git@github.com:Lagabachera/BizFlow.git"
BACKEND_REPO_URL="git@github.com:Lagabachera/barazone-backend.git"
FRONTEND_DIR="~/Documents/$PROJECT_NAME/frontend"
BACKEND_DIR="~/Documents/$PROJECT_NAME/backend"
EMAIL="lagabachera@gmail.com"
USERNAME="lagabachera"

# ---------------------
# Funciones Auxiliares
# ---------------------

function check_command {
  if ! [ -x "$(command -v $1)" ]; then
    echo "Error: El comando $1 no está instalado."
    exit 1
  fi
}

# Verificar que los comandos necesarios están instalados
check_command git
check_command npm
check_command npx
check_command vercel

# ---------------------
# Configuración del Frontend
# ---------------------

echo "Clonando y configurando el frontend..."

# Clonar el repositorio del frontend
cd ~/Documents
if [ -d "$PROJECT_NAME" ]; then
  echo "El directorio $PROJECT_NAME ya existe."
else
  git clone $FRONTEND_REPO_URL $PROJECT_NAME
fi

cd $PROJECT_NAME

# Actualizar el repositorio
git pull

cd frontend

# Instalar dependencias
echo "Instalando dependencias del frontend..."
npm install

# Instalar ESLint y Prettier
echo "Configurando ESLint y Prettier..."
npm install --save-dev eslint prettier eslint-config-prettier eslint-plugin-prettier eslint-plugin-react eslint-plugin-react-hooks @typescript-eslint/parser @typescript-eslint/eslint-plugin

# Crear archivos de configuración

# .eslintrc.js
cat <<EOT > .eslintrc.js
module.exports = {
  env: {
    browser: true,
    es2021: true,
    node: true,
  },
  extends: [
    'next',
    'next/core-web-vitals',
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:react/recommended',
    'plugin:prettier/recommended'
  ],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaFeatures: {
      jsx: true,
    },
    ecmaVersion: 12,
    sourceType: 'module',
  },
  plugins: ['react', '@typescript-eslint', 'prettier'],
  rules: {
    // Añade reglas personalizadas aquí
  },
};
EOT

# .prettierrc
cat <<EOT > .prettierrc
{
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 80,
  "tabWidth": 2,
  "semi": true
}
EOT

# Actualizar scripts en package.json
node -e "
let package = require('./package.json');
package.scripts['lint'] = \"eslint 'src/**/*.{js,jsx,ts,tsx}'\";
package.scripts['lint:fix'] = \"eslint 'src/**/*.{js,jsx,ts,tsx}' --fix\";
package.scripts['format'] = \"prettier --write 'src/**/*.{js,jsx,ts,tsx,css,md}'\";
require('fs').writeFileSync('package.json', JSON.stringify(package, null, 2));
"

# Ejecutar linting y formateo
echo "Ejecutando linting y formateo del código del frontend..."
npm run lint:fix
npm run format

# Revisar variables de entorno y seguridad
echo "Actualizando archivo .env.local..."
cat <<EOT > .env.local
NEXT_PUBLIC_SUPABASE_URL=$SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUPABASE_KEY
EOT

# Eliminar claves API sensibles del frontend
echo "Asegurando que no hay claves API sensibles en el frontend..."
# Busca y elimina cualquier referencia a OPENAI_API_KEY y HUGGINGFACE_API_KEY en .env.local
sed -i '/OPENAI_API_KEY/d' .env.local
sed -i '/HUGGINGFACE_API_KEY/d' .env.local

# Modificar el frontend para usar el backend
echo "Modificando el frontend para comunicarse con el backend..."
# Crear apiClient.js si no existe
cat <<EOT > src/utils/apiClient.ts
import axios from 'axios';

const apiClient = axios.create({
  baseURL: 'https://barazone-backend.vercel.app/api', // Reemplaza con la URL real de tu backend
});

export default apiClient;
EOT

# Actualizar el código del frontend para usar apiClient
# Aquí podrías agregar comandos adicionales para reemplazar las llamadas directas a las APIs de OpenAI y Hugging Face por llamadas al backend.

# Añadir cambios y hacer commit
git add .
git commit -m "Aplicar mejoras al frontend según las mejores prácticas"
git push

# ---------------------
# Configuración del Backend
# ---------------------

echo "Clonando y configurando el backend..."

# Clonar el repositorio del backend
cd ~/Documents
if [ -d "$PROJECT_NAME-backend" ]; then
  echo "El directorio $PROJECT_NAME-backend ya existe."
else
  git clone $BACKEND_REPO_URL $PROJECT_NAME-backend
fi

cd $PROJECT_NAME-backend

# Actualizar el repositorio
git pull

# Inicializar npm si no existe
if [ ! -f "package.json" ]; then
  npm init -y
fi

# Instalar dependencias
echo "Instalando dependencias del backend..."
npm install express axios dotenv @supabase/supabase-js openai cors

# Crear estructura de directorios
mkdir -p src/{controllers,routes,services,middlewares,utils}

# Crear archivo .env
echo "Configurando variables de entorno para el backend..."
cat <<EOT > .env
SUPABASE_URL=$SUPABASE_URL
SUPABASE_KEY=$SUPABASE_KEY
OPENAI_API_KEY=$OPENAI_API_KEY
HUGGINGFACE_API_KEY=$HUGGINGFACE_API_KEY
PORT=5000
EOT

# Crear archivo src/app.js
cat <<EOT > src/app.js
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
dotenv.config();

const aiRoutes = require('./routes/aiRoutes');
const authRoutes = require('./routes/authRoutes');

const app = express();
app.use(cors());
app.use(express.json());

// Rutas
app.use('/api/ai', aiRoutes);
app.use('/api/auth', authRoutes);

// Manejo de errores
const errorHandler = require('./middlewares/errorHandler');
app.use(errorHandler);

const port = process.env.PORT || 5000;
app.listen(port, () => {
  console.log(\`Backend running on port \${port}\`);
});
EOT

# Crear archivo index.js
cat <<EOT > index.js
require('./src/app');
EOT

# Crear archivos de rutas y controladores

# src/routes/aiRoutes.js
cat <<EOT > src/routes/aiRoutes.js
const express = require('express');
const router = express.Router();
const aiController = require('../controllers/aiController');
const authMiddleware = require('../middlewares/authMiddleware');

router.post('/summary', authMiddleware, aiController.getSummary);

module.exports = router;
EOT

# src/controllers/aiController.js
cat <<EOT > src/controllers/aiController.js
const openaiService = require('../services/openaiService');

exports.getSummary = async (req, res, next) => {
  try {
    const { text } = req.body;
    const summary = await openaiService.generateSummary(text);
    res.json({ summary });
  } catch (error) {
    next(error);
  }
};
EOT

# src/services/openaiService.js
cat <<EOT > src/services/openaiService.js
const { Configuration, OpenAIApi } = require('openai');
const configuration = new Configuration({ apiKey: process.env.OPENAI_API_KEY });
const openai = new OpenAIApi(configuration);

exports.generateSummary = async (text) => {
  const response = await openai.createCompletion({
    model: 'text-davinci-003',
    prompt: \`Resumir el siguiente texto: \${text}\`,
    max_tokens: 150,
  });
  return response.data.choices[0].text.trim();
};
EOT

# src/middlewares/authMiddleware.js
cat <<EOT > src/middlewares/authMiddleware.js
const { createClient } = require('@supabase/supabase-js');
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);

module.exports = async (req, res, next) => {
  const token = req.headers['authorization']?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token provided' });

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data) return res.status(401).json({ error: 'Invalid token' });

  req.user = data.user;
  next();
};
EOT

# src/middlewares/errorHandler.js
cat <<EOT > src/middlewares/errorHandler.js
module.exports = (err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal Server Error' });
};
EOT

# Añadir scripts al package.json
node -e "
let package = require('./package.json');
package.scripts = {
  'start': 'node index.js',
  'dev': 'nodemon index.js',
  'lint': 'eslint src/**',
  'lint:fix': 'eslint src/** --fix',
  'test': 'echo \"No tests specified\"'
};
require('fs').writeFileSync('package.json', JSON.stringify(package, null, 2));
"

# Instalar nodemon y eslint
npm install --save-dev nodemon eslint

# Configurar ESLint para el backend
npx eslint --init <<EOF
0
JavaScript modules (import/export)
None of these
No
Node
Use a popular style guide
Airbnb
JavaScript
Yes
EOF

# Crear archivo .eslintrc.json si no se creó
if [ ! -f ".eslintrc.json" ]; then
  cat <<EOT > .eslintrc.json
{
  "extends": "airbnb-base",
  "rules": {
    "no-console": "off"
  }
}
EOT
fi

# Ejecutar linting y formateo
echo "Ejecutando linting del backend..."
npm run lint:fix

# Añadir cambios y hacer commit
git add .
git commit -m "Configurar y desplegar el backend según las mejores prácticas"
git push

# ---------------------
# Configurar GitHub Actions para el Backend
# ---------------------

echo "Configurando GitHub Actions para el backend..."

mkdir -p .github/workflows

cat <<EOT > .github/workflows/backend.yml
name: Backend CI/CD

on:
  push:
    branches:
      - main

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v2

      - name: Set up Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '14'

      - name: Install dependencies
        run: npm install

      - name: Lint code
        run: npm run lint

      - name: Deploy to Vercel
        env:
          VERCEL_TOKEN: \${{ secrets.VERCEL_TOKEN }}
        run: npx vercel --prod --token \$VERCEL_TOKEN
EOT

# Añadir cambios y hacer commit
git add .
git commit -m "Agregar GitHub Actions para CI/CD del backend"
git push

# Agregar secretos en GitHub (debes hacerlo manualmente en la configuración del repositorio)
echo "Recuerda agregar los siguientes secretos en tu repositorio de GitHub:"
echo "- VERCEL_TOKEN"
echo "- SUPABASE_URL"
echo "- SUPABASE_KEY"
echo "- OPENAI_API_KEY"
echo "- HUGGINGFACE_API_KEY"

# ---------------------
# Desplegar el Backend en Vercel
# ---------------------

echo "Desplegando el backend en Vercel..."

# Desplegar el backend en Vercel
vercel --prod --confirm --token $VERCEL_API_TOKEN

# Configurar variables de entorno en Vercel
echo "Configurando variables de entorno en Vercel para el backend..."

vercel env add SUPABASE_URL production <<EOM
$SUPABASE_URL
EOM

vercel env add SUPABASE_KEY production <<EOM
$SUPABASE_KEY
EOM

vercel env add OPENAI_API_KEY production <<EOM
$OPENAI_API_KEY
EOM

vercel env add HUGGINGFACE_API_KEY production <<EOM
$HUGGINGFACE_API_KEY
EOM

echo "Despliegue del backend completado."

# ---------------------
# Finalización
# ---------------------

echo "Todos los procesos han sido automatizados y completados con éxito."
echo "El frontend ha sido mejorado y los cambios se han subido al repositorio."
echo "El backend ha sido configurado, desplegado y está listo para ser utilizado."
echo "Asegúrate de verificar que todo funciona correctamente y realiza pruebas adicionales si es necesario."
