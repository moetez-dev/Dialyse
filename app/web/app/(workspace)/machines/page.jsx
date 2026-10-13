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
    addHref="/machines/ajout_machine/"
    addLabel="Ajouter un générateur"
    detailPath="/machines/details/{id}/"
  />;
}
