BDD_DIR=bdd
SERVEUR_DIR=server
FRONT_DIR=front
IMG_DIR=img
SERVER_NB=1

default: build

build:
	make -C $(IMG_DIR) build
	make -C $(BDD_DIR) build
	make -C $(SERVEUR_DIR) build
	make -C $(FRONT_DIR) build
	make -C $(IMG_DIR) clean

reset:
	make -C $(SERVEUR_DIR) reset
	make -C $(BDD_DIR) reset

start:
	make -C $(BDD_DIR) start
	number=1 ; while [ $$number -le $(SERVER_NB) ] ; do \
		make -C $(SERVEUR_DIR) start ; \
		number=`expr $$number + 1` ; \
	done
	make -C $(FRONT_DIR) start

stop:
	make -C $(FRONT_DIR) stop
	make -C $(SERVEUR_DIR) stop
	make -C $(BDD_DIR) stop

check:
	make -C $(BDD_DIR) check || true
	make -C $(SERVEUR_DIR) check || true
	make -C $(FRONT_DIR) check || true

clean:
	make -C $(FRONT_DIR) clean
	make -C $(SERVEUR_DIR) clean
	make -C $(BDD_DIR) clean
	make -C $(IMG_DIR) clean

clean_data:
	make -C $(BDD_DIR) clean_data
	make -C $(SERVEUR_DIR) clean_data
