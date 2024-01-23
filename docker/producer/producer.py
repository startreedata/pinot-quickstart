#!/bin/local/python

import time
import random
import json
import os
import logging
from faker import Faker
import pandas as pd

from confluent_kafka import Producer

class Generator:
     
     def next() -> (str, object):
          pass

class RatingGenerator(Generator):

    def __init__(self):
        Faker.seed(0)
        self.faker = Faker()
        path = os.getenv('DATA')
        if(path is None):
            raise Exception("need to movies.json file")
        self.df = pd.read_json(path, lines=True)
    
    def next(self):
        key = random.randint(self.df['movieId'].min(), self.df['movieId'].max())
        data = json.dumps({
              "movieId": key,
              "rating": round(random.uniform(0.0, 1.0), 2),
              "ratingTime": round(time.time() * 1000)
        })
        return str(key), data.encode('utf-8')
         


def delivery_report(err, msg):
    """ Called once for each message produced to indicate delivery result.
        Triggered by poll() or flush(). """
    if err is not None:
        print('Message delivery failed: {}'.format(err))
    else:
        print('Message delivered to {} [{}]'.format(msg.topic(), msg.partition()))


def send(p, topic, gen:Generator, limit:int=100000):
    p.poll(0)
    
    for i in range(limit):    
        key, data = gen.next()
        p.produce(
            key=key,
            topic=topic, 
            value=data, 
            on_delivery=delivery_report)
        
    # Wait for any outstanding messages to be delivered and delivery report
    # callbacks to be triggered.
    p.flush()

if __name__== "__main__":
    bootstrap = os.getenv('BOOTSTRAPSERVER','kafka:9092')
    topic = os.getenv('TOPIC','data')
    limit = int(os.getenv('LIMIT', 100000))
    
    logging.basicConfig(level=logging.INFO)
    p = Producer({'bootstrap.servers': bootstrap})
    gen = RatingGenerator()

    send(p, topic=topic, gen=gen, limit=limit)

