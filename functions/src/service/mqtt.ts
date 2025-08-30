import * as mqtt from 'mqtt';

const logger = require("firebase-functions/logger");

export interface SensorData {
  temperature?: number;
  humidity?: number;
  soilMoisture?: number;
}

export class MqttService {
  private timeout: number;

  constructor(
    public username: string,
    public password: string,
    timeout: number = 10000, // Aumentado para 10 segundos
  ) {
    this.timeout = timeout;
  }

  async readSensorData(
    brokerUrl: string, 
    stationId: string
  ): Promise<SensorData> {
    return new Promise((resolve, reject) => {
      // Para HiveMQ Cloud, usar protocol seguro e porta correta
      const isHiveMQ = brokerUrl.includes('hivemq.cloud');
      let connectUrl = brokerUrl;
      let options: mqtt.IClientOptions = {
        username: this.username,
        password: this.password,
        connectTimeout: 30000, // 30 segundos para dar mais tempo
        reconnectPeriod: 0,
        keepalive: 60
      };

      if (isHiveMQ) {
        connectUrl = `mqtts://${brokerUrl}:8883`;
        options.protocol = 'mqtts';
        options.port = 8883;
        logger.info(`Conectando ao HiveMQ Cloud: ${connectUrl}`);
      } else {
        connectUrl = `mqtt://${brokerUrl}`;
        logger.info(`Conectando ao broker MQTT: ${connectUrl}`);
      }

      logger.info(`Tentando conectar com usuário: ${this.username}`);
      
      const client = mqtt.connect(connectUrl, options);
      

      const data: SensorData = {};
      let timeoutHandler: NodeJS.Timeout;

      client.on('connect', () => {
        logger.info(`Conectado à estação ${stationId} via MQTT`);
        
        client.publish('esp32/', 'Ler sensor', (publishErr) => {
          if (publishErr) {
            logger.error(`Erro ao publicar comando para estação ${stationId}:`, publishErr);
            client.end();
            reject(publishErr);
            return;
          }

          logger.info(`Comando 'Ler sensor' enviado para estação ${stationId}`);
        });
        
        // Subscrever aos tópicos de dados
        client.subscribe(['esp32/umidade-solo', 'esp32/umidade', 'esp32/temperatura'], (err) => {
          if (err) {
            logger.error(`Erro ao subscrever tópicos para estação ${stationId}:`, err);
            client.end();
            reject(err);
            return;
          }

        });
        
        // Timeout para receber todos os dados
        timeoutHandler = setTimeout(() => {
          const receivedCount = Object.keys(data).length;
          logger.info(`Timeout atingido para estação ${stationId}. Dados recebidos (${receivedCount}/3):`, data);
          client.end();
          resolve(data);
        }, this.timeout);
      });

      client.on('message', (topic, message) => {
        try {
          const value = parseFloat(message.toString());
          
          if (isNaN(value)) {
            logger.warn(`Valor inválido recebido em ${topic}: ${message.toString()}`);
            return;
          }

          logger.info(`Estação ${stationId} - Recebido ${topic}: ${value}`);
          
          switch (topic) {
            case 'esp32/umidade-solo':
              data.soilMoisture = value;
              break;
            case 'esp32/umidade':
              data.humidity = value;
              break;
            case 'esp32/temperatura':
              data.temperature = value;
              break;
          }

          // Se recebeu todos os dados, finalizar
          if (this.hasAllSensorData(data)) {
            clearTimeout(timeoutHandler);
            client.end();
            logger.info(`Todos os dados recebidos para estação ${stationId}:`, data);
            resolve(data);
          }
        } catch (error) {
          logger.error(`Erro ao processar mensagem ${topic} para estação ${stationId}:`, error);
        }
      });

      client.on('error', (error) => {
        logger.error(`Erro MQTT para estação ${stationId}:`, error);
        clearTimeout(timeoutHandler);
        client.end();
        reject(error);
      });

      client.on('close', () => {
        logger.info(`Conexão MQTT fechada para estação ${stationId}`);
      });
    });
  }

  private hasAllSensorData(data: SensorData): boolean {
    return data.soilMoisture !== undefined && 
           data.humidity !== undefined && 
           data.temperature !== undefined;
  }

  publishIrrigationCommand(mmWater: string, brokerUrl: string, stationId: string){
    // Para HiveMQ Cloud, usar protocol seguro e porta correta
    const isHiveMQ = brokerUrl.includes('hivemq.cloud');
    let connectUrl = brokerUrl;
    let options: mqtt.IClientOptions = {
      username: this.username,
      password: this.password,
      connectTimeout: 30000,
      reconnectPeriod: 0,
      keepalive: 60
    };

    if (isHiveMQ) {
      connectUrl = `mqtts://${brokerUrl}:8883`;
      options.protocol = 'mqtts';
      options.port = 8883;
    } else {
      connectUrl = `mqtt://${brokerUrl}`;
    }

    const client = mqtt.connect(connectUrl, options);
    
    client.on('connect', () => {
      logger.info(`Conectado à estação ${stationId} via MQTT`);
      client.publish('esp32/', `Irrigar:${mmWater}`, (publishErr) => {
        if (publishErr) {
          logger.error(`Erro ao publicar comando de irrigação:`, publishErr);
          client.end();
          return;
        }
        logger.info(`Comando de irrigação publicado: Irrigar:${mmWater}`);
      });
    });
  }
}