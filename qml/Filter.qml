import QtQuick 2.15

Item {
    id: component
    property alias model: filterModel

    property QtObject sourceModel: undefined
    property string filter: ""
    property string v
    property string property: "name"

    Connections {
        // onFilterChanged: invalidateFilter()
        // onPropertyChanged: invalidateFilter()
        // onSourceModelChanged: invalidateFilter()
        function onFilterChanged(){
            component.v=component.filter.toLowerCase()
            invalidateFilter(component.v)
        }
        // function onPropertyChanged(){
        //     invalidateFilter(component.v)
        // }
        // function onSourceModelChanged(){
        //     invalidateFilter(component.v)
        // }
    }
    Component.onCompleted: filterModel.append(JSON.parse(backend.filter(' ')))//invalidateFilter()

    ListModel {
        id: filterModel
    }


    // filters out all items of source model that does not match filter
    function invalidateFilter(fil) {
        if (sourceModel === undefined)
            //sourceModel.load()
            return;
        filterModel.clear();

        if (!isFilteringPropertyOk())
            return

        //var length = sourceModel.count
        //sourceModel.clear()
        filterModel.append(JSON.parse(backend.filter(fil)))
        // sourceModel.append(sourceModel.filter(fil))
        // for(let item of sourceModel.filter(fil)){
        //     if(item.name.substr(0,fil.length)===fil){
                // console.log(item.name)
        //         filterModel.append(item)
        //     }
        // }
        // for (var i = 0; i < length; ++i) {
        //     var item = sourceModel.get(i);
        //     if (isAcceptedItem(item,fil)) {
        //         filterModel.append(item)
        //         //sourceModel.remove(i)
        //         //console.log('✅ 👇️');
        //     }
        // }
    }


    // returns true if item is accepted by filter
    function isAcceptedItem(item,fil) {
        if (item.name === undefined)
            return false

        if (!item.name.toLowerCase().startsWith(fil.toLowerCase())) {
            // 👇️ this runs
            //console.log(fil);//'✅ string starts with ',
            return false
        }
        // if (item[component.property].match(this.filter) === null) {
        //     return false
        // }
        return true
    }

    // checks if it has any sence to process invalidating based on property
    function isFilteringPropertyOk() {
        if(this.property === undefined || this.property === "") {
            return false
        }
        return true
    }
}

