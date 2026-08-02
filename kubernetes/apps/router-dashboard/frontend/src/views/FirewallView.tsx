import { useState, useEffect } from 'react';

const API_URL = import.meta.env.VITE_API_URL || '';

export default function FirewallView() {
  const [rules, setRules] = useState<any[]>([]);
  
  useEffect(() => {
    fetch(`${API_URL}/api/firewall`)
      .then(res => res.json())
      .then(d => {
        if(Array.isArray(d)) setRules(d);
      });
  }, []);

  return (
    <div className="bg-panel rounded-xl border border-slate-700/50 overflow-hidden shadow-xl">
      <div className="px-6 py-4 border-b border-slate-700/50 bg-slate-800/50">
        <h3 className="text-lg font-medium text-white">Firewall Filter Rules</h3>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm text-left">
          <thead className="text-xs text-slate-400 uppercase bg-slate-900/50">
            <tr>
              <th className="px-6 py-3">#</th>
              <th className="px-6 py-3">Action</th>
              <th className="px-6 py-3">Chain</th>
              <th className="px-6 py-3">Protocol</th>
              <th className="px-6 py-3">Comment</th>
            </tr>
          </thead>
          <tbody>
            {rules.map((rule, i) => (
              <tr key={i} className={`border-b border-slate-700/50 transition-colors ${rule.disabled === 'true' ? 'opacity-50' : ''} hover:bg-slate-800/50`}>
                <td className="px-6 py-4 font-mono text-xs text-slate-500">{rule['.id']}</td>
                <td className="px-6 py-4">
                  <span className={`text-xs px-2 py-1 rounded font-medium ${rule.action === 'accept' || rule.action === 'fasttrack-connection' ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'}`}>
                    {rule.action}
                  </span>
                </td>
                <td className="px-6 py-4 text-slate-300 font-medium">{rule.chain}</td>
                <td className="px-6 py-4 font-mono text-xs text-isar">{rule.protocol || 'any'}</td>
                <td className="px-6 py-4 text-slate-400">{rule.comment || '-'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
