import React from "react";
import Hero from "./(sections)/Hero";
import Stats from "./(sections)/Stats";
import Product from "./(sections)/Product";
import Compliance from "./(sections)/Compliance";
import Docs from "./(sections)/Docs";
import CTA from "./(sections)/CTA";

export default function HomePage() {
  return (
    <main className="min-h-screen w-full bg-gradient-to-br from-zinc-50 via-white to-amber-50 text-zinc-900">
      <header className="max-w-6xl mx-auto px-6 pt-10 pb-6 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="h-10 w-10 rounded-xl bg-gradient-to-br from-amber-500 to-amber-600 flex items-center justify-center">
            <span className="text-white font-bold text-sm">FTH</span>
          </div>
          <h1 className="text-xl font-bold tracking-tight">Future Tech Holdings</h1>
        </div>
        <nav className="hidden md:flex items-center gap-6 text-sm">
          <a href="#product" className="hover:underline transition-colors">Product</a>
          <a href="#compliance" className="hover:underline transition-colors">Compliance</a>
          <a href="#docs" className="hover:underline transition-colors">Docs</a>
          <a href="#contact" className="hover:underline transition-colors">Contact</a>
        </nav>
      </header>

      <Hero />
      <Stats />
      <Product />
      <Compliance />
      <Docs />
      <CTA />

      <footer className="max-w-6xl mx-auto px-6 pb-12 text-sm text-zinc-500 text-center">
        <div className="border-t border-zinc-200 pt-8">
          <p>© {new Date().getFullYear()} Future Tech Holdings — All rights reserved.</p>
          <p className="mt-2">Dubai DMCC Licensed • Private Placement • Accredited Investors Only</p>
        </div>
      </footer>
    </main>
  );
}