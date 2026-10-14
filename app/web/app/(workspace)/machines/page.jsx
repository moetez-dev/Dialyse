import { ResourceList } from '../../../components/resource-list';

export const metadata = { title: 'Générateurs | Dialyse Manager' };

export default function MachinesPage() {
  return <ResourceList
    title="Générateurs"
    description="Parc de générateurs et état de disponibilité."
    endpoint="/api/machines/"
    columns={[
      { key: 'machine_id', label: 'Identifiant' },
      { key: 'model', label: 'Modèle' },
      { key: 'manufacturer', label: 'Fabricant' },
      { key: 'location', label: 'Salle' },
      { key: 'status', label: 'État', kind: 'status', statusKind: 'machine' },
    ]}
    searchable
    createRoles={['admin', 'technicien']}
    createEndpoint="/api/machines/"
    createFields={[
      { name: 'machine_id', label: 'Identifiant', required: true, maxLength: 50 },
      { name: 'model', label: 'Modèle', required: true, maxLength: 100 },
      { name: 'manufacturer', label: 'Fabricant', maxLength: 100 },
      { name: 'location', label: 'Salle', required: true, maxLength: 100 },
    ]}
    addHref="/machines/ajout_machine/"
    addLabel="Ajouter un générateur"
    detailPath="/machines/details/{id}/"
  />;
}
