## 1. FIRST SET UP TYPESCRIPT + DOCKER

dotenv as a dependency

## 2. STEPS TO RUN EXPRESS SERVER + TYPESCRIPT (TESTING PURPOSE ONLY)

npx tsc
node dist/index.js

## UPDATE SCRIPTS ADDED, NOW RUN FOLLOWING COMMAND

npm run build
npm run start

you can also run these commands by splitting terminal

tsc -w
npm run dev

## RUN APPLICATION USING DOCKER

docker-compose -f docker-compose.yml up -d

shut down app

docker-compose down
