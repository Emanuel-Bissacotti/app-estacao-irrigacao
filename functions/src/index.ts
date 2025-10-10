/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import { FirestoreService } from "./service/firestore";
import { User } from "./entities/user";
import { MqttService } from "./service/mqtt";
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Inicializa o Firebase Admin
admin.initializeApp();

export const scheduleDataGet = functions
  .region('us-central1')
  .pubsub
  .schedule('every 1 hours')
  .timeZone('America/Sao_Paulo')
  .onRun(async (context) => {
  functions.logger.info("-----------Start scheduledDataGet--------------");
  
  try {
    const firestoreService = new FirestoreService(admin.firestore());
    
    const userSnapshot = await firestoreService.users.get();
    const users = userSnapshot.docs.map(doc => doc.data() as User);
    
    functions.logger.info(`Encontrados ${users.length} usuários`);
    
    if (users.length === 0) {
      functions.logger.info("Nenhum usuário encontrado no banco de dados");
      return null;
    }
    
    for (const user of users) {
      functions.logger.info("Processando usuário:", { uid: user.uid, email: user.email });
      
      if (!user.emailMqtt || !user.passwordMqtt) {
        functions.logger.warn(`Usuário ${user.uid} não possui credenciais MQTT válidas`);
        continue;
      }
      
      const mqttService = new MqttService(user.emailMqtt, user.passwordMqtt, 15000); // 15 segundos para dar tempo suficiente
      const irrigationStations = await firestoreService.getIrrigationStations(user.uid);
      
      functions.logger.info(`Encontradas ${irrigationStations.length} estações para usuário ${user.uid}`);
      
      for (const station of irrigationStations) {
        if (!station.urlMqtt) {
          functions.logger.warn(`Estação ${station.uid} não possui URL MQTT válida`);
          continue;
        }
        
        if (!station.uid || station.uid.trim() === '') {
          functions.logger.warn(`Estação sem UID válido encontrada, pulando...`);
          continue;
        }
        
        try {
          const sensorData = await mqttService.readSensorData(station.urlMqtt, station.uid);
          functions.logger.info("Dados do sensor recebidos:", { stationId: station.uid, ...sensorData });
          
          let irrigatedAmount = 0;
          
          if (sensorData.soilMoisture !== undefined && sensorData.soilMoisture <= station.percentForIrrigation && station.millimetersWater > 0) {
            functions.logger.info(`Iniciando irrigação para a estação ${station.uid}`);
            mqttService.publishIrrigationCommand(station.millimetersWater.toString(), station.urlMqtt, station.uid);
            irrigatedAmount = station.millimetersWater;
          } else {
            functions.logger.info(`Nenhuma irrigação necessária para a estação ${station.uid}`);
          }

          // Só salvar dados se pelo menos um dos valores não for undefined
          const hasValidData = sensorData.soilMoisture !== undefined || 
                              sensorData.humidity !== undefined || 
                              sensorData.temperature !== undefined;
                              
          if (hasValidData) {
            try {
              // Construir caminho de forma mais segura
              const collectionPath = `users/${user.uid}/irrigation_stations/${station.uid}/data`;
              functions.logger.info(`Salvando dados no caminho: ${collectionPath}`);
              
              await firestoreService.addData(
                sensorData.soilMoisture,
                sensorData.humidity,
                sensorData.temperature,
                collectionPath,
                irrigatedAmount
              );
              functions.logger.info(`Dados salvos no Firestore para estação ${station.uid}`);
            } catch (saveError) {
              functions.logger.error(`Erro ao salvar dados no Firestore para estação ${station.uid}:`, saveError);
            }
          } else {
            functions.logger.warn(`Nenhum dado válido recebido para salvar da estação ${station.uid}`);
          }
        } catch (stationError) {
          functions.logger.error(`Erro ao processar estação ${station.uid}:`, stationError);
        }
      }
    }
    
  } catch (error) {
    functions.logger.error("Erro na função agendada:", error);
  }
  
  functions.logger.info("-----------End scheduledDataGet--------------");
  return null;
});