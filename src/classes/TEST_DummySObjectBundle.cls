@IsTest 
public class TEST_DummySObjectBundle {
	private Map<SObjectField, TEST_DummySObjectBundle> sObjectBundleBySObjectFieldMap 
		= new Map<SObjectField, TEST_DummySObjectBundle>();

	private Map<SObjectField, List<SObject>> sObjectListBySObjectFieldMap 
		= new Map<SObjectField, List<SObject>>();

	public TEST_DummySObjectBundle put(SObjectField sObjectField, List<SObject> sObjectList) {
		this.sObjectListBySObjectFieldMap.put(sObjectField, sObjectList);
		return this;
	}
		
	public TEST_DummySObjectBundle put(SObjectField sObjectField, TEST_DummySObjectBundle sObjectBundle) {
		this.sObjectBundleBySObjectFieldMap.put(sObjectField, sObjectBundle);
		return this;
	}
	
	public TEST_DummySObjectBundle getBundle(SObjectField sObjectField) {
		return this.sObjectBundleBySObjectFieldMap.get(sObjectField);
	}  

	public List<SObject> getList(SObjectField sObjectField) {
		return this.sObjectListBySObjectFieldMap.get(sObjectField);
	}  
}