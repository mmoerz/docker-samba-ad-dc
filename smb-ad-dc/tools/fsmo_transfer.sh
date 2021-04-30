#!/bin/bash

ROLES="SchemaMasterRole \
InfrastructureMasterRole \
RidAllocationMasterRole \
PdcEmulationMasterRole \
DomainNamingMasterRole \
DomainDnsZonesMasterRole \
ForestDnsZonesMasterRole"

#ACTION=seize
ACTION=transfer

for role in ${ROLES} ; do 
  samba-tool fsmo ${ACTION} --role=$rolea
done
