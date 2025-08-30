import { CollectionGroup, Firestore } from "firebase-admin/firestore";
import { User } from "../entities/user";
import { IrrigationStation } from "../entities/irrigationStation";
import { Data } from "../entities/data";

export class FirestoreService {
    constructor(
        public db: Firestore,
    ) { }

    get users(): CollectionGroup<User> {
        return this.db.collectionGroup("users") as CollectionGroup<User>;
    }

    async getIrrigationStations(userUid: string): Promise<IrrigationStation[]> {
        const snapshot = await this.db.collection(`users/${userUid}/irrigation_stations`).get();
        return snapshot.docs.map(doc => doc.data() as IrrigationStation);
    }

    addData(soilHumidity: number | undefined, humidity: number | undefined, temperature: number | undefined, collection: string, irrigated: number | undefined){
        // Gerar um ID único
        const docRef = this.db.collection(collection).doc();
        const documentId = docRef.id;
        
        const data = new Data(
            temperature,
            humidity,
            soilHumidity,
            irrigated,
            documentId  // Usar o mesmo ID do documento
        );
        
        // Filtrar propriedades undefined antes de salvar no Firestore
        const cleanData: any = {};
        Object.keys(data).forEach(key => {
            const value = (data as any)[key];
            if (value !== undefined) {
                cleanData[key] = value;
            }
        });
        
        // Usar set() em vez de add() para garantir que o ID do documento seja o mesmo
        return docRef.set(cleanData);
    }
}