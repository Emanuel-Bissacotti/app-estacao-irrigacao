import { Timestamp } from "firebase-admin/firestore";

export class Data {
    constructor(
        public temperature?: number,
        public airHumidity?: number,
        public soilHumidity?: number,
        public irrigatedMillimeters?: number,
        public uid?: string,
        public date: Timestamp = Timestamp.now()
    ) {}
}
