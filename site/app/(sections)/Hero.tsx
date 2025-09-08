import React from "react";

const Card = ({ children, className = "" }: { children: React.ReactNode; className?: string }) => (
  <div className={`rounded-2xl shadow-lg border p-6 bg-white/90 backdrop-blur ${className}`}>
    {children}
  </div>
);

const Button = ({ 
  children, 
  className = "", 
  onClick,
  ...props 
}: { 
  children: React.ReactNode; 
  className?: string; 
  onClick?: () => void;
  [key: string]: any;
}) => (
  <button 
    className={`rounded-2xl px-6 py-3 font-semibold shadow transition-all duration-200 ${className}`} 
    onClick={onClick}
    {...props}
  >
    {children}
  </button>
);

export default function Hero() {
  return (
    <section className="max-w-6xl mx-auto px-6 py-16 grid md:grid-cols-2 gap-12 items-center">
      <div className="space-y-8">
        <div>
          <h2 className="text-4xl md:text-5xl font-extrabold leading-tight">
            Asset‑Backed Finance, 
            <span className="text-amber-600 block">Done Right</span>.
          </h2>
          <p className="mt-6 text-lg text-zinc-600 leading-relaxed">
            FTH‑G: a private, compliance‑native, gold‑backed program with verifiable reserves,
            monthly USDT distributions, and institutional audit trails.
          </p>
        </div>
        
        <div className="flex flex-wrap gap-4">
          <Button 
            className="bg-amber-600 text-white hover:bg-amber-700 hover:scale-105 px-8"
            onClick={() => document.getElementById('docs')?.scrollIntoView({behavior:'smooth'})}
          >
            View Documentation
          </Button>
          <Button className="bg-white border border-zinc-200 hover:bg-zinc-50 hover:border-amber-200 text-zinc-900">
            Request Access
          </Button>
        </div>
        
        <div className="text-sm text-zinc-500 bg-zinc-100/50 rounded-lg p-4">
          <div className="flex items-center gap-2 mb-2">
            <div className="w-2 h-2 rounded-full bg-amber-500"></div>
            <span className="font-medium">Private Placement Notice</span>
          </div>
          <p>Available exclusively to accredited and qualified investors. Compliance screening required.</p>
        </div>
      </div>

      <div className="space-y-6">
        <Card className="bg-gradient-to-br from-white/90 to-amber-50/90">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-semibold text-zinc-800">Program Snapshot</h3>
            <div className="w-3 h-3 rounded-full bg-green-500 animate-pulse"></div>
          </div>
          
          <div className="grid grid-cols-2 gap-6">
            <div className="space-y-1">
              <div className="text-sm text-zinc-500">Gold Backing</div>
              <div className="font-bold text-zinc-900">1:1 vaulted (≥105%)</div>
            </div>
            <div className="space-y-1">
              <div className="text-sm text-zinc-500">Entry Rails</div>
              <div className="font-bold text-zinc-900">USDT, ETH Multi-chain</div>
            </div>
            <div className="space-y-1">
              <div className="text-sm text-zinc-500">Lock Period</div>
              <div className="font-bold text-zinc-900">5 months cliff</div>
            </div>
            <div className="space-y-1">
              <div className="text-sm text-zinc-500">Distributions</div>
              <div className="font-bold text-amber-600">5–10% monthly</div>
            </div>
          </div>
        </Card>

        <Card className="bg-gradient-to-br from-zinc-900 to-zinc-800 text-white">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-8 h-8 rounded-lg bg-amber-500 flex items-center justify-center">
              <span className="text-xs font-bold">🏛️</span>
            </div>
            <span className="font-semibold">Dubai DMCC Licensed</span>
          </div>
          <p className="text-sm text-zinc-300">
            Fully regulated precious metals trading license with UAE government oversight and international compliance.
          </p>
        </Card>
      </div>
    </section>
  );
}