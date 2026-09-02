/**
 * Proves `XFTY_GenerationContext` - the constructor guards and null defaults, and
 * the `forRelated()` / `forRecord()` / `forValueField()` derivation transforms.
 * Pure in-memory state, no DML/SOQL.
 */
@IsTest
private class XFTY_GenerationContextTest {

    private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();

    private static XFTY_GenerationContext context(XFTY_InsertModeEnum mode, XFTY_InsertInclusivityEnum inclusivity) {
        return new XFTY_GenerationContext(LOOKUP, mode, inclusivity);
    }

    // Constructor -----------------------------------------------------

    @IsTest
    static void testConstructor_whenGivenARunConfiguration_keepsIt() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        XFTY_GenerationContext ctx = context(XFTY_InsertModeEnum.NOW, XFTY_InsertInclusivityEnum.ALL);
        Test.stopTest();

        // Assert
        Assert.areEqual(LOOKUP, ctx.providerLookup);
        Assert.areEqual(XFTY_InsertModeEnum.NOW, ctx.insertMode);
        Assert.areEqual(XFTY_InsertInclusivityEnum.ALL, ctx.inclusivity);
    }

    @IsTest
    static void testConstructor_whenTheProviderLookupIsNull_throws() {
        // Arrange
        // nothing to arrange

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            new XFTY_GenerationContext(null, XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown);
        Assert.isTrue(thrown.getMessage().contains('Provider Lookup'), thrown.getMessage());
    }

    @IsTest
    static void testConstructor_whenTheModeIsNull_defaultsToNever() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        XFTY_GenerationContext ctx = context(null, null);
        Test.stopTest();

        // Assert
        Assert.areEqual(XFTY_InsertModeEnum.NEVER, ctx.insertMode);
    }

    @IsTest
    static void testConstructor_whenTheInclusivityIsNull_defaultsToNone() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        XFTY_GenerationContext ctx = context(null, null);
        Test.stopTest();

        // Assert
        Assert.areEqual(XFTY_InsertInclusivityEnum.NONE, ctx.inclusivity);
    }

    @IsTest
    static void testConstructor_hasNoPerRecordState() {
        // Arrange
        // nothing to arrange

        // Act
        Test.startTest();
        XFTY_GenerationContext ctx = context(XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE);
        Test.stopTest();

        // Assert
        Assert.isNull(ctx.recordBeingBuilt);
        Assert.isNull(ctx.bundleSoFar);
        Assert.areEqual(-1, ctx.rowIndex);
    }

    // forRelated() --------------------------------------------------

    @IsTest
    static void testForRelated_whenTheModeIsRelatedOnly_becomesNow() {
        // Arrange
        XFTY_GenerationContext base = context(XFTY_InsertModeEnum.RELATED_ONLY, XFTY_InsertInclusivityEnum.REQUIRED);

        // Act
        Test.startTest();
        XFTY_GenerationContext related = base.forRelated();
        Test.stopTest();

        // Assert
        Assert.areEqual(XFTY_InsertModeEnum.NOW, related.insertMode, 'ancestors of a RELATED_ONLY run are inserted');
        Assert.areEqual(XFTY_InsertInclusivityEnum.REQUIRED, related.inclusivity, 'inclusivity is unchanged');
    }

    @IsTest
    static void testForRelated_whenTheInclusivityIsPreventCascade_becomesNone() {
        // Arrange
        XFTY_GenerationContext base = context(XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.PREVENT_CASCADE);

        // Act
        Test.startTest();
        XFTY_GenerationContext related = base.forRelated();
        Test.stopTest();

        // Assert
        Assert.areEqual(XFTY_InsertInclusivityEnum.NONE, related.inclusivity, 'the cascade stops one level down');
        Assert.areEqual(XFTY_InsertModeEnum.MOCK, related.insertMode, 'insert mode is unchanged');
    }

    @IsTest
    static void testForRelated_forAnyOtherModeAndInclusivity_carriesThemThrough() {
        // Arrange
        XFTY_GenerationContext base = context(XFTY_InsertModeEnum.NOW, XFTY_InsertInclusivityEnum.ALL);

        // Act
        Test.startTest();
        XFTY_GenerationContext related = base.forRelated();
        Test.stopTest();

        // Assert
        Assert.areEqual(XFTY_InsertModeEnum.NOW, related.insertMode);
        Assert.areEqual(XFTY_InsertInclusivityEnum.ALL, related.inclusivity);
        Assert.areEqual(LOOKUP, related.providerLookup, 'the Provider Lookup is always carried through');
    }

    @IsTest
    static void testForRelated_clearsAnyPerRecordState() {
        // Arrange
        XFTY_GenerationContext scoped = context(XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.ALL)
                .forRecord(new Account(), new XFTY_DummySObjectBundle(), 0);

        // Act
        Test.startTest();
        XFTY_GenerationContext related = scoped.forRelated();
        Test.stopTest();

        // Assert
        Assert.isNull(related.recordBeingBuilt, 'descending into ancestors drops the current record');
        Assert.areEqual(-1, related.rowIndex);
    }

    // forRecord() --------------------------------------------------

    @IsTest
    static void testForRecord_scopesToOneRecordAndKeepsTheRunSettings() {
        // Arrange
        Account record = new Account(Name = 'ctx');
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectBundle();

        // Act
        Test.startTest();
        XFTY_GenerationContext scoped = context(XFTY_InsertModeEnum.NOW, XFTY_InsertInclusivityEnum.REQUIRED)
                .forRecord(record, bundle, 2);
        Test.stopTest();

        // Assert
        Assert.areEqual(record, scoped.recordBeingBuilt);
        Assert.areEqual(bundle, scoped.bundleSoFar);
        Assert.areEqual(2, scoped.rowIndex);
        Assert.areEqual(XFTY_InsertModeEnum.NOW, scoped.insertMode, 'the run settings are unchanged');
        Assert.areEqual(XFTY_InsertInclusivityEnum.REQUIRED, scoped.inclusivity);
        Assert.areEqual(LOOKUP, scoped.providerLookup);
    }

    // forValueField() / siblingValue() ---------------------------

    @IsTest
    static void testSiblingValue_whenTheSiblingIsAlreadyResolved_returnsItsValue() {
        // Arrange
        XFTY_GenerationContext atField = context(XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE)
                .forRecord(new Account(Name = 'sib', Site = 'HQ'), new XFTY_DummySObjectBundle(), 0)
                .forValueField(Account.Description, new Set<SObjectField>{ Account.Type });

        // Act
        Test.startTest();
        Object siteValue = atField.siblingValue(Account.Site);
        Test.stopTest();

        // Assert
        Assert.areEqual('HQ', siteValue);
    }

    @IsTest
    static void testSiblingValue_whenTheSiblingIsStillPending_throws() {
        // Arrange
        XFTY_GenerationContext atField = context(XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE)
                .forRecord(new Account(Name = 'sib', Site = 'HQ'), new XFTY_DummySObjectBundle(), 0)
                .forValueField(Account.Description, new Set<SObjectField>{ Account.Type });

        // Act
        XFTY_DummySObjectFtyProviderException thrown;
        Test.startTest();
        try {
            atField.siblingValue(Account.Type);
        } catch (XFTY_DummySObjectFtyProviderException ex) {
            thrown = ex;
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(thrown, 'Account.Type is still pending, not a misleading null');
        Assert.isTrue(thrown.getMessage().contains('Type'), thrown.getMessage());
        Assert.isTrue(thrown.getMessage().contains('Description'), thrown.getMessage());
    }

    // withForcedRelationshipPaths() -----------------------------

    @IsTest
    static void testWithForcedRelationshipPaths_whenGivenNull_tolerantlyKeepsAnEmptyList() {
        // Arrange
        XFTY_GenerationContext base = context(XFTY_InsertModeEnum.MOCK, XFTY_InsertInclusivityEnum.NONE);

        // Act
        Test.startTest();
        XFTY_GenerationContext ctx = base.withForcedRelationshipPaths(null);
        Test.stopTest();

        // Assert
        Assert.isNotNull(ctx.forcedRelationshipPaths);
        Assert.isTrue(ctx.forcedRelationshipPaths.isEmpty());
    }

    // forBatchedInsert() - the flag is carried through every derivation --

    @IsTest
    static void testForBatchedInsert_onAPlainContext_theFlagIsFalse() {
        // Arrange
        XFTY_GenerationContext base = context(XFTY_InsertModeEnum.NEVER, XFTY_InsertInclusivityEnum.ALL);

        // Act
        Test.startTest();
        Boolean pending = base.batchedInsertPending;
        Test.stopTest();

        // Assert
        Assert.isFalse(pending, 'a plain run is not a batched-insert run');
    }

    @IsTest
    static void testForBatchedInsert_setsTheFlag() {
        // Arrange
        XFTY_GenerationContext base = context(XFTY_InsertModeEnum.NEVER, XFTY_InsertInclusivityEnum.ALL);

        // Act
        Test.startTest();
        Boolean pending = base.forBatchedInsert().batchedInsertPending;
        Test.stopTest();

        // Assert
        Assert.isTrue(pending);
    }

    @IsTest
    static void testWithForcedRelationshipPaths_carriesTheBatchedInsertFlagThrough() {
        // Arrange
        XFTY_GenerationContext batched = batchedContext();

        // Act
        Test.startTest();
        XFTY_GenerationContext derived = batched.withForcedRelationshipPaths(null);
        Test.stopTest();

        // Assert
        Assert.isTrue(derived.batchedInsertPending);
    }

    @IsTest
    static void testForRelated_carriesTheBatchedInsertFlagDownToAncestors() {
        // Arrange
        XFTY_GenerationContext batched = batchedContext();

        // Act
        Test.startTest();
        XFTY_GenerationContext derived = batched.forRelated();
        Test.stopTest();

        // Assert
        Assert.isTrue(derived.batchedInsertPending);
    }

    @IsTest
    static void testForRecord_carriesTheBatchedInsertFlagIntoTheValuePass() {
        // Arrange
        XFTY_GenerationContext batched = batchedContext();

        // Act
        Test.startTest();
        XFTY_GenerationContext derived = batched.forRecord(new Account(), new XFTY_DummySObjectBundle(), 0);
        Test.stopTest();

        // Assert
        Assert.isTrue(derived.batchedInsertPending);
    }

    private static XFTY_GenerationContext batchedContext() {
        return context(XFTY_InsertModeEnum.NEVER, XFTY_InsertInclusivityEnum.ALL).forBatchedInsert();
    }
}
