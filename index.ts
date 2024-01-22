import { config } from 'dotenv';
config();
import express, { Express, Request, Response } from "express"

const app: Express = express();

app.get("/", (req: Request, res: Response) => {
    res.send("HELLO WORLD MAMA MIA")
})

app.listen(process.env.PORT, () => {
    console.log(`Now listening on port ${process.env.PORT}`);

})


