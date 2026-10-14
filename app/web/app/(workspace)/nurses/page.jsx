import { ResourceList } from '../../../components/resource-list';

export const metadata = { title: 'Infirmiers | Dialyse Manager' };

export default function NursesPage() {
  return <ResourceList
    title="Infirmiers"
    description="Comptes et disponibilité de l’équipe infirmière."
    endpoint="/api/nurses/"
    columns={[
      { key: 'username', label: 'Nom' },
      { key: 'email', label: 'E-mail' },
      { key: 'phone', label: 'Téléphone' },
      { key: 'staff_status', label: 'État', kind: 'status', statusKind: 'staff' },
      { key: 'date_inscription', label: 'Inscription', kind: 'date' },
    ]}
    searchable
    createRoles={['admin']}
    createEndpoint="/api/nurses/"
    createFields={[
      { name: 'username', label: 'Nom', required: true, maxLength: 150 },
      { name: 'email', label: 'E-mail', type: 'email', required: true },
      { name: 'phone', label: 'Téléphone', maxLength: 20 },
    ]}
    addHref="/nurses/ajouter/"
    addLabel="Ajouter un infirmier"
    detailPath="/nurse/{id}/"
  />;
}
