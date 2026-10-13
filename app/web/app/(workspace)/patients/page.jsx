import { ResourceList } from '../../../components/resource-list';

export const metadata = { title: 'Patients | Dialyse Manager' };

export default function PatientsPage() {
  return <ResourceList
    title="Patients"
    eyebrow="RÉFÉRENTIEL"
    description="Dossiers patients et informations de suivi."
    endpoint="/api/patients/"
    columns={[
      { key: 'full_name', label: 'Patient' },
      { key: 'age', label: 'Âge' },
      { key: 'type_de_dialyse', label: 'Type de dialyse' },
      { key: 'telephone', label: 'Téléphone' },
      { key: 'groupe_sanguin', label: 'Groupe sanguin' },
    ]}
    searchable
    addHref="/patients/add/"
    addLabel="Nouveau patient"
    detailPath="/patients/profile/{id}/"
  />;
}
