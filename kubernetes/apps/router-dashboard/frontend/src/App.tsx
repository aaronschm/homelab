import { useState, useEffect } from 'react';
import { Network, Shield, Users, RadioTower } from 'lucide-react';
import WireGuardView from './views/WireGuardView';
import InterfacesView from './views/InterfacesView';
import ClientsView from './views/ClientsView';
import FirewallView from './views/FirewallView';

const API_URL = import.meta.env.VITE_API_URL || '';

interface RouterInfo { id: string; label: string; ip: string; }

function App() {
  const [activeTab, setActiveTab] = useState('wireguard');
  const [routers, setRouters] = useState<RouterInfo[]>([]);
  const [activeRouter, setActiveRouter] = useState('primary');

  useEffect(() => {
    fetch(`${API_URL}/api/routers`)
      .then(r => r.json())
      .then((data: RouterInfo[]) => { setRouters(data); })
      .catch(() => setRouters([{ id: 'primary', label: 'Router', ip: '' }]));
  }, []);

  const tabs = [
    { id: 'wireguard', name: 'WireGuard', icon: <Shield size={18} /> },
    { id: 'interfaces', name: 'Interfaces', icon: <RadioTower size={18} /> },
    { id: 'clients', name: 'Clients', icon: <Users size={18} /> },
    { id: 'firewall', name: 'Firewall', icon: <Network size={18} /> }
  ];

  return (
    <div className="min-h-screen flex bg-bgdark font-sans text-slate-300">
      {/* Sidebar */}
      <aside className="w-64 bg-panel border-r border-slate-700/50 flex flex-col">
        <div className="p-6 flex items-center gap-3">
          <div className="w-8 h-8 rounded bg-isar flex items-center justify-center text-bgdark font-bold">
            <RadioTower size={20} />
          </div>
          <span className="text-xl font-bold tracking-tight text-white">Isar<span className="text-isar">Cloud</span></span>
        </div>
        
        {/* Router selector — only shown when multiple routers are configured */}
        {routers.length > 1 && (
          <div className="px-4 mb-2">
            <label className="block text-xs text-slate-500 mb-1 uppercase tracking-wide">Device</label>
            <select
              value={activeRouter}
              onChange={e => setActiveRouter(e.target.value)}
              className="w-full bg-slate-900 border border-slate-700 rounded px-3 py-2 text-sm text-white outline-none focus:border-isar"
            >
              {routers.map(r => <option key={r.id} value={r.id}>{r.label}</option>)}
            </select>
          </div>
        )}

        <nav className="flex-1 px-4 space-y-2 mt-4">
          {tabs.map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                activeTab === tab.id 
                  ? 'bg-isar/10 text-isar font-medium border border-isar/20' 
                  : 'hover:bg-slate-800 text-slate-400 hover:text-slate-200'
              }`}
            >
              {tab.icon}
              {tab.name}
            </button>
          ))}
        </nav>
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-auto">
        <header className="h-16 border-b border-slate-700/50 flex items-center px-8 bg-panel/50 backdrop-blur-sm sticky top-0 z-10">
          <h2 className="text-lg font-medium text-slate-200">
            {tabs.find(t => t.id === activeTab)?.name}
          </h2>
        </header>
        
        <div className="p-8 max-w-6xl mx-auto">
          {activeTab === 'wireguard' && <WireGuardView router={activeRouter} />}
          {activeTab === 'interfaces' && <InterfacesView router={activeRouter} />}
          {activeTab === 'clients' && <ClientsView router={activeRouter} />}
          {activeTab === 'firewall' && <FirewallView router={activeRouter} />}
        </div>
      </main>
    </div>
  );
}

export default App;
