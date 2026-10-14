import { ResourceList } from '../../../components/resource-list';

export const metadata = { title: 'Docteurs | Dialyse Manager' };

export default function DoctorsPage() {
  return <ResourceList
    title="Docteurs"
    description="Comptes médecins et administrateurs."
    endpoint="/api/doctors/"
    columns={[
      { key: 'username', label: 'Nom' },
      { key: 'email', label: 'E-mail' },
      { key: 'phone', label: 'Téléphone' },
      { key: 'specialite', label: 'Spécialité' },
      { key: 'staff_status', label: 'État', kind: 'status', statusKind: 'staff' },
    ]}
    searchable
    createRoles={['admin']}
    createEndpoint="/api/doctors/"
    createFields={[
      { name: 'username', label: 'Nom complet', required: true, maxLength: 150 },
      { name: 'email', label: 'E-mail', type: 'email', required: true },
      { name: 'specialite', label: 'Spécialité', maxLength: 100 },
      { name: 'phone', label: 'Téléphone', maxLength: 20 },
    ]}
    addHref="/add-doctor/"
    addLabel="Ajouter un docteur"
    detailPath="/doctor/{id}/"
  />;
}
