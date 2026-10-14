import { ResourceList } from '../../../components/resource-list';

export const metadata = { title: 'Patients | Dialyse Manager' };

export default function PatientsPage() {
  return <ResourceList
    title="Patients"
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
    createEndpoint="/api/patients/"
    createFields={[
      { name: 'first_name', label: 'Prénom', required: true, maxLength: 50 },
      { name: 'last_name', label: 'Nom', required: true, maxLength: 50 },
      { name: 'date_of_birth', label: 'Date de naissance', type: 'date', required: true },
      {
        name: 'groupe_sanguin',
        label: 'Groupe sanguin',
        required: true,
        options: [
          ['A+', 'A+'], ['A-', 'A-'], ['B+', 'B+'], ['B-', 'B-'],
          ['AB+', 'AB+'], ['AB-', 'AB-'], ['O+', 'O+'], ['O-', 'O-'],
        ],
      },
      { name: 'telephone', label: 'Téléphone', required: true, maxLength: 15 },
      { name: 'adresse', label: 'Adresse', required: true, maxLength: 255 },
      { name: 'contact_urgence', label: "Contact d'urgence", required: true, maxLength: 15 },
      { name: 'antecedents_medicaux', label: 'Antécédents médicaux', maxLength: 255, multiline: true },
    ]}
    addHref="/patients/add/"
    addLabel="Nouveau patient"
    detailPath="/patients/profile/{id}/"
  />;
}
