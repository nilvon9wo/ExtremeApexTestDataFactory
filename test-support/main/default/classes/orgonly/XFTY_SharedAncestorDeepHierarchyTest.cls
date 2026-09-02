/**
 * The Shared Ancestors deep-hierarchy acceptance test.
 *
 * `XFTY_HierarchyNode__c` (test-support) has a self-parent lookup and 10 record
 * types forming a strict downward chain `Level9 -> ... -> Level1 -> Root`. Each
 * level's parent record type is fixed by `PARENT_RT_BY_CHILD`. `Root` is a
 * **singleton** - the `XFTY_HierarchyNodeRootSingleton` trigger rejects a second
 * one.
 *
 * Ask for a `Level9` node, `REQUIRED` + `NOW`. The whole ancestor chain must be
 * generated, each with the right record type, **every chain converging on the
 * one shared `Root`** - two `supply()` calls for different leaves land on the
 * same `Root` Id. Without shared ancestors the second chain inserts its own
 * `Root` and the singleton trigger blows up.
 *
 * In `test-support/orgonly/` - needs the custom object's real record-type
 * describe, which the local Apex runtime does not have. Runs on a scratch org
 * or any Developer Edition org.
 *
 * Neither a scratch nor a dev org admin sees a custom object's record types by
 * default. Each method assigns the `XFTY_HierarchyNodeRecordTypes` permission
 * set (setup-object DML, so it is done *before* the `System.runAs` block that
 * follows - the `runAs` boundary keeps it clear of the framework's own DML) and
 * runs its body inside `System.runAs`, because a permission-set assignment made
 * in a test only takes effect inside a subsequent `runAs`. No `@TestSetup` -
 * the framework's incrementing / unique value expressions rely on static
 * counters that a `@TestSetup` method would perturb.
 */
@IsTest
private class XFTY_SharedAncestorDeepHierarchyTest {

    private static final SObjectType NODE = XFTY_HierarchyNode__c.SObjectType;
    private static final User RUNNING_USER = new User(Id = UserInfo.getUserId());

    private static void grantRecordTypeVisibility() {
        List<PermissionSet> sets = [SELECT Id FROM PermissionSet WHERE Name = 'XFTY_HierarchyNodeRecordTypes'];
        if (sets.isEmpty()) {
            return;
        }
        try {
            insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = sets[0].Id);
        } catch (DmlException alreadyAssigned) {
            // fine on a re-run in a persistent org - the assignment already exists
        }
    }

    // Root is the top; every other level's parent record type is the one below it here.
    private static final Map<String, String> PARENT_RT_BY_CHILD = new Map<String, String>{
            'Level9' => 'Level8', 'Level8' => 'Level7', 'Level7' => 'Level6',
            'Level6' => 'Level5', 'Level5' => 'Level4', 'Level4' => 'Level3',
            'Level3' => 'Level2', 'Level2' => 'Level1', 'Level1' => 'Root'
    };

    @IsTest
    static void testSupply_forTwoDeepLeaves_theirChainsConvergeOnTheOneSharedRoot() {
      grantRecordTypeVisibility();
      System.runAs(RUNNING_USER) {
        // Arrange - register Root + Level1..Level8 as shared ancestors, each carrying its own parent
        configureSharedSpine();
        XFTY_DummySObjectProviderLookupIntf lookup = hierarchyLookup();

        // Act - two independent Level9 leaves
        XFTY_HierarchyNode__c eastLeaf;
        XFTY_HierarchyNode__c westLeaf;
        Test.startTest();
        eastLeaf = (XFTY_HierarchyNode__c) supplyLeaf(lookup);
        westLeaf = (XFTY_HierarchyNode__c) supplyLeaf(lookup);
        Test.stopTest();

        // Assert - one shared node for Root + Level1..Level8 (9) + one Level9 per leaf (2) = 11
        Assert.areEqual(11, [SELECT COUNT() FROM XFTY_HierarchyNode__c], 'one shared node per level, one Level9 per leaf');
        Assert.areEqual(eastLeaf.Parent__c, westLeaf.Parent__c, 'both Level9 leaves share the one Level8');

        Id rootId = XFTY_SharedAncestor.getId('Root');
        Assert.areEqual(1, [SELECT COUNT() FROM XFTY_HierarchyNode__c WHERE RecordTypeId = :rtId('Root')]);
        Assert.areEqual(rootId, walkToRoot(eastLeaf.Id), 'east chain reaches the shared Root');
        Assert.areEqual(rootId, walkToRoot(westLeaf.Id), 'west chain reaches the same shared Root');

        // every generated node carries the record type its level demands
        for (XFTY_HierarchyNode__c node : [
                SELECT RecordTypeId, RecordType.DeveloperName, Parent__c, Parent__r.RecordType.DeveloperName
                FROM XFTY_HierarchyNode__c
        ]) {
            if (node.Parent__c == null) {
                Assert.areEqual('Root', node.RecordType.DeveloperName, 'only Root has no parent');
                continue;
            }
            String expectedParentRt = PARENT_RT_BY_CHILD.get(node.RecordType.DeveloperName);
            Assert.areEqual(expectedParentRt, node.Parent__r.RecordType.DeveloperName,
                    node.RecordType.DeveloperName + ' parent record type');
        }
      }
    }

    @IsTest
    static void testSupply_afterTheSharedRootExists_aSecondRootCannotBeInserted() {
      grantRecordTypeVisibility();
      System.runAs(RUNNING_USER) {
        // Arrange
        configureSharedSpine();
        supplyLeaf(hierarchyLookup());   // builds the one Root

        // Act
        DmlException thrown;
        try {
            insert new XFTY_HierarchyNode__c(Name = 'Rogue Root', RecordTypeId = rtId('Root'));
        } catch (DmlException ex) {
            thrown = ex;
        }

        // Assert
        Assert.isNotNull(thrown, 'the singleton trigger rejects a second Root');
        Assert.isTrue(thrown.getMessage().contains('one'), thrown.getMessage());
      }
    }

    // Fixture -----------------------------------------------------------------

    private static SObject supplyLeaf(XFTY_DummySObjectProviderLookupIntf lookup) {
        return new XFTY_DummySObjectProvider(rtKey('Level9'), lookup)
                .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
                .setInsertMode(XFTY_InsertModeEnum.NOW)
                .supply();
    }

    private static void configureSharedSpine() {
        XFTY_SharedAncestor.put('Root', new XFTY_HierarchyNode__c(Name = 'Root')).fromVariant(rtKey('Root'));
        for (String childRt : new List<String>{
                'Level1', 'Level2', 'Level3', 'Level4', 'Level5', 'Level6', 'Level7', 'Level8'
        }) {
            XFTY_SharedAncestor.put(childRt, new XFTY_HierarchyNode__c(Name = childRt))
                    .fromVariant(rtKey(childRt))
                    .putRequired(XFTY_HierarchyNode__c.Parent__c, XFTY_SharedAncestor.get(PARENT_RT_BY_CHILD.get(childRt)))
                    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED);
        }
    }

    private static XFTY_DummySObjectProviderLookupIntf hierarchyLookup() {
        Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> byKey =
                new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>();
        for (String rt : new List<String>{
                'Root', 'Level1', 'Level2', 'Level3', 'Level4', 'Level5', 'Level6', 'Level7', 'Level8', 'Level9'
        }) {
            byKey.put(rtKey(rt), new NodeProvider(rt));
        }
        return XFTY_ProviderLookups.of(byKey);
    }

    private static XFTY_LookupKeyIntf rtKey(String developerName) {
        return XFTY_RecordTypeLookupKey.get(NODE, developerName);
    }

    private static Id rtId(String developerName) {
        return NODE.getDescribe().getRecordTypeInfosByDeveloperName().get(developerName).getRecordTypeId();
    }

    private static Id walkToRoot(Id nodeId) {
        XFTY_HierarchyNode__c node = [SELECT Id, Parent__c FROM XFTY_HierarchyNode__c WHERE Id = :nodeId];
        while (node.Parent__c != null) {
            node = [SELECT Id, Parent__c FROM XFTY_HierarchyNode__c WHERE Id = :node.Parent__c];
        }
        return node.Id;
    }

    /** One Provider per record type; a non-Root level requires its fixed-record-type parent as a shared ancestor. */
    private class NodeProvider implements XFTY_DummySobjectProviderIntf {
        private final XFTY_DummySObjectMasterTemplate template;

        private NodeProvider(String recordTypeDeveloperName) {
            this.template = new XFTY_DummySObjectMasterTemplate(XFTY_HierarchyNode__c.Id)
                    .put(XFTY_HierarchyNode__c.Name, new XFTY_IncrementingStringExpression(recordTypeDeveloperName))
                    .put(XFTY_HierarchyNode__c.RecordTypeId, rtId(recordTypeDeveloperName));
            if (PARENT_RT_BY_CHILD.containsKey(recordTypeDeveloperName)) {
                this.template.putRequired(
                        XFTY_HierarchyNode__c.Parent__c,
                        XFTY_SharedAncestor.get(PARENT_RT_BY_CHILD.get(recordTypeDeveloperName))
                );
            }
        }

        public SObjectField getPrimaryTargetField() {
            return XFTY_HierarchyNode__c.Id;
        }
        public XFTY_DummySObjectMasterTemplate getMasterTemplate() {
            return this.template;
        }
        public XFTY_DummySObjectBundle createBundle(XFTY_GenerationContext context, List<SObject> templates) {
            return XFTY_DummySObjectFactory.createBundle(context, this.template, templates);
        }
    }
}
