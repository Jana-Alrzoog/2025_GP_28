import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";
import emailjs from '@emailjs/browser'

emailjs.init('zRX2gpxOt5DM0-v39')

createRoot(document.getElementById("root")!).render(<App />);