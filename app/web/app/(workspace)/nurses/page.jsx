import { ResourceList } from '../../../components/resource-list';

export const metadata = { title: 'Infirmiers | Dialyse Manager' };

export default function NursesPage() {
  return <ResourceList
    title="Infirmiers"
    eyebrow="ÉQUIPE"
    description="Comptes et disponibilité de l’équipe infirmière."
    endpoint="/api/nurses/"
    columns={[
      { key: 'username', label: 'Nom' },
      { key: 'email', label: 'E-mail' },
      { key: 'phone', label: 'Téléphone' },
      { key: 'staff_status', label: 'État', kind: 'status' },
      { key: 'date_inscription', label: 'Inscription', kind: 'date' },
    ]}
    searchable
    createRoles={['admin']}
    addHref="/nurses/ajouter/"
    addLabel="Ajouter un infirmier"
    detailPath="/nurse/{id}/"
  />;
}
