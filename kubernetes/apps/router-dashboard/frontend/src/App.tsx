import { useState, useEffect } from 'react';

function App() {
  const [interfaces, setInterfaces] = useState<any[]>([]);

  useEffect(() => {
    fetch(import.meta.env.VITE_API_URL + '/api/interfaces')
      .then(res => res.json())
      .then(data => {
        if(Array.isArray(data)) setInterfaces(data);
      });
  }, []);

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold mb-4">Router Dashboard</h1>
      <div className="bg-white rounded shadow p-4">
        <h2 className="text-xl mb-2">Interfaces</h2>
        <ul>
          {interfaces.map((iface, i) => (
            <li key={i} className="mb-2 p-2 border-b">
              <span className="font-bold">{iface.name}</span> - {iface.type} ({iface.disabled === 'false' ? 'Up' : 'Down'})
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

export default App;
