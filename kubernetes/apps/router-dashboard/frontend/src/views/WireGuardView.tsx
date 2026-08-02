import { useState, useEffect } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { x25519 } from '@noble/curves/ed25519';

const API_URL = import.meta.env.VITE_API_URL || '';

// Generate a WireGuard-compatible keypair entirely in the browser.
// The private key NEVER leaves this browser tab — only the public key is sent
// to the backend, which registers it with the router.
function generateWireGuardKeypair(): { privateKey: string; publicKey: string } {
  const privKeyBytes = x25519.utils.randomPrivateKey();
  const pubKeyBytes = x25519.getPublicKey(privKeyBytes);
  return {
    privateKey: btoa(String.fromCharCode(...privKeyBytes)),
    publicKey: btoa(String.fromCharCode(...pubKeyBytes)),
  };
}

export default function WireGuardView({ router = 'primary' }: { router?: string }) {
  const [data, setData] = useState<{interfaces: any[], peers: any[]}>({ interfaces: [], peers: [] });
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [newPeer, setNewPeer] = useState({ interfaceName: '', comment: '', allowedAddress: '10.10.30.2/32', endpointHost: 'isarcloud.eu' });
  const [generatedConfig, setGeneratedConfig] = useState<string | null>(null);

  const fetchData = () => {
    fetch(`${API_URL}/api/wireguard?target=${router}`)
      .then(res => res.json())
      .then(d => {
        setData(d);
        if (!newPeer.interfaceName && d.interfaces.length > 0) {
          setNewPeer(prev => ({ ...prev, interfaceName: d.interfaces[0].name }));
        }
        setLoading(false);
      });
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 5000);
    return () => clearInterval(interval);
  }, [router]);

  const toggleInterface = async (id: string, currentlyDisabled: boolean) => {
    await fetch(`${API_URL}/api/wireguard/toggle`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, disabled: !currentlyDisabled, target: router })
    });
    fetchData();
  };

  const handleAddPeer = async (e: React.FormEvent) => {
    e.preventDefault();
    // Generate keypair IN THE BROWSER — private key stays here, never sent to server.
    const { privateKey, publicKey } = generateWireGuardKeypair();

    const res = await fetch(`${API_URL}/api/wireguard/peer`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...newPeer, clientPublicKey: publicKey, target: router })
    });
    const result = await res.json();
    if (result.success) {
      // Build the complete WireGuard config locally using the local private key
      // and the server info returned by the API (server pubkey + endpoint).
      const config = `[Interface]
PrivateKey = ${privateKey}
Address = ${newPeer.allowedAddress}

[Peer]
PublicKey = ${result.serverPublicKey}
Endpoint = ${result.endpoint}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
`;
      setGeneratedConfig(config);
      fetchData();
    } else {
      alert("Error adding peer: " + result.error);
    }
  };

  const downloadConfig = () => {
    if (!generatedConfig) return;
    const blob = new Blob([generatedConfig], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${newPeer.comment.replace(/\s+/g, '_') || 'wg_client'}.conf`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  if (loading) return <div className="text-slate-500">Loading...</div>;

  return (
    <div className="space-y-6 relative">
      <div className="bg-panel rounded-xl border border-slate-700/50 overflow-hidden shadow-xl">
        <div className="px-6 py-4 border-b border-slate-700/50 bg-slate-800/50">
          <h3 className="text-lg font-medium text-white">WireGuard Interfaces</h3>
        </div>
        <div className="p-6 grid gap-4">
            {data.interfaces.map(iface => (
              <div key={iface['.id']} className="flex items-center justify-between p-4 rounded-lg bg-slate-900/50 border border-slate-700/50 hover:border-slate-600">
                <div>
                  <div className="flex items-center gap-3">
                    <div className={`w-2.5 h-2.5 rounded-full ${iface.disabled === 'false' ? 'bg-emerald-500 shadow-[0_0_10px_rgba(16,185,129,0.5)]' : 'bg-rose-500'}`}></div>
                    <span className="font-medium text-white text-lg">{iface.name}</span>
                  </div>
                  <div className="text-sm text-slate-400 mt-1 pl-5.5">Port: {iface['listen-port']} | MTU: {iface.mtu}</div>
                </div>
                <button 
                  onClick={() => toggleInterface(iface['.id'], iface.disabled === 'true')}
                  className={`px-4 py-2 rounded-md font-medium text-sm transition-colors ${iface.disabled === 'false' ? 'bg-rose-500/10 text-rose-500 hover:bg-rose-500/20' : 'bg-emerald-500/10 text-emerald-500 hover:bg-emerald-500/20'}`}
                >
                  {iface.disabled === 'false' ? 'Disable' : 'Enable'}
                </button>
              </div>
            ))}
        </div>
      </div>

      <div className="bg-panel rounded-xl border border-slate-700/50 overflow-hidden shadow-xl">
        <div className="px-6 py-4 border-b border-slate-700/50 bg-slate-800/50 flex justify-between items-center">
          <h3 className="text-lg font-medium text-white">Peers</h3>
          <button onClick={() => setShowAddModal(true)} className="bg-isar hover:bg-isar-light text-bgdark font-medium px-4 py-1.5 rounded text-sm transition-colors">
            + Add Peer
          </button>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-slate-400 uppercase bg-slate-900/50">
              <tr>
                <th className="px-6 py-3">Comment</th>
                <th className="px-6 py-3">Interface</th>
                <th className="px-6 py-3">Allowed IPs</th>
                <th className="px-6 py-3">Endpoint</th>
              </tr>
            </thead>
            <tbody>
              {data.peers.map(peer => (
                <tr key={peer['.id']} className={`border-b border-slate-700/50 hover:bg-slate-800/50 transition-colors ${peer.disabled === 'true' ? 'opacity-50' : ''}`}>
                  <td className="px-6 py-4 font-medium text-white">{peer.comment || '-'}</td>
                  <td className="px-6 py-4 text-isar">{peer.interface}</td>
                  <td className="px-6 py-4 font-mono text-xs bg-slate-900/30 rounded inline-block mx-6 my-3 px-2 py-1">{peer['allowed-address']}</td>
                  <td className="px-6 py-4">{peer['endpoint-address'] ? `${peer['endpoint-address']}:${peer['endpoint-port']}` : '-'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {showAddModal && (
        <div className="fixed inset-0 bg-bgdark/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-panel border border-slate-700 rounded-xl shadow-2xl max-w-md w-full p-6">
            <h3 className="text-xl font-medium text-white mb-4">Add WireGuard Peer</h3>
            
            {!generatedConfig ? (
              <form onSubmit={handleAddPeer} className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-slate-400 mb-1">Interface</label>
                  <select 
                    value={newPeer.interfaceName} 
                    onChange={e => setNewPeer({...newPeer, interfaceName: e.target.value})}
                    className="w-full bg-slate-900 border border-slate-700 rounded p-2 text-white outline-none focus:border-isar"
                  >
                    {data.interfaces.map(i => <option key={i.name} value={i.name}>{i.name}</option>)}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-slate-400 mb-1">Device Name / Comment</label>
                  <input type="text" required value={newPeer.comment} onChange={e => setNewPeer({...newPeer, comment: e.target.value})} className="w-full bg-slate-900 border border-slate-700 rounded p-2 text-white outline-none focus:border-isar" placeholder="e.g. Aaron's iPhone" />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-slate-400 mb-1">Allowed IP</label>
                    <input type="text" required value={newPeer.allowedAddress} onChange={e => setNewPeer({...newPeer, allowedAddress: e.target.value})} className="w-full bg-slate-900 border border-slate-700 rounded p-2 text-white outline-none focus:border-isar" placeholder="10.10.30.2/32" />
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-slate-400 mb-1">Server Endpoint</label>
                    <input type="text" required value={newPeer.endpointHost} onChange={e => setNewPeer({...newPeer, endpointHost: e.target.value})} className="w-full bg-slate-900 border border-slate-700 rounded p-2 text-white outline-none focus:border-isar" placeholder="home.aaronschmidt.de" />
                  </div>
                </div>
                <div className="flex justify-end gap-3 mt-6">
                  <button type="button" onClick={() => setShowAddModal(false)} className="px-4 py-2 text-slate-400 hover:text-white transition-colors">Cancel</button>
                  <button type="submit" className="bg-isar hover:bg-isar-light text-bgdark font-medium px-6 py-2 rounded transition-colors">Generate</button>
                </div>
              </form>
            ) : (
              <div className="space-y-6 flex flex-col items-center">
                <div className="bg-white p-4 rounded-lg">
                  <QRCodeSVG value={generatedConfig} size={256} />
                </div>
                <div className="w-full">
                  <p className="text-sm text-emerald-400 mb-2 text-center">Config generated and peer added to router!</p>
                  <textarea readOnly value={generatedConfig} className="w-full h-32 bg-slate-900 text-slate-300 font-mono text-xs p-3 rounded border border-slate-700" />
                </div>
                <div className="flex justify-between w-full">
                  <button onClick={() => { setShowAddModal(false); setGeneratedConfig(null); setNewPeer({...newPeer, comment: ''}); }} className="px-4 py-2 text-slate-400 hover:text-white transition-colors">Close</button>
                  <button onClick={downloadConfig} className="bg-isar hover:bg-isar-light text-bgdark font-medium px-4 py-2 rounded transition-colors">Download .conf</button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
