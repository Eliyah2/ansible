-- Schema voor de demo-website van het Ansible-lab.
CREATE TABLE IF NOT EXISTS bezoekers (
    id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    bezocht_op DATETIME     NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB;
