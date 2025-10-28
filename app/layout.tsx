import "./globals.css";

export const metadata = {
  title: "PeaceDAO Demo",
  description: "Token-verified DAO governance prototype",
};

export default function RootLayout({ children }: { children: any }) {
  return (
    <html lang="en">
      <body className="font-sans">
        {children}
      </body>
    </html>
  );
}
