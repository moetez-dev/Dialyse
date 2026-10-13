import { ResourceList } from '../../../components/resource-list';

export const metadata = { title: 'Docteurs | Dialyse Manager' };

export default function DoctorsPage() {
  return <ResourceList
    title="Docteurs"
    eyebrow="ÉQUIPE"
    description="Comptes médecins et administrateurs."
    endpoint="/api/doctors/"
    columns={[
      { key: 'username', label: 'Nom' },
      { key: 'email', label: 'E-mail' },
      { key: 'phone', label: 'Téléphone' },
      { key: 'specialite', label: 'Spécialité' },
      { key: 'staff_status', label: 'État', kind: 'status' },
    ]}
    searchable
    createRoles={['admin']}
    addHref="/add-doctor/"
    addLabel="Ajouter un docteur"
    detailPath="/doctor/{id}/"
  />;
}
