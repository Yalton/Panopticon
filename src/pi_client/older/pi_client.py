from sensors import client
import time

def main():

    #talking to broker
    pub = client()
    driver = pub.connect()
    
    driver.loop_start()
    while True:

        print("\n...publishing...")

        #call to recive sensor data

        pub.send(driver,"cock")
        time.sleep(1)
    driver.loop_stop()
    # driver.loop_forever() 


if __name__ == "__main__":
    main()